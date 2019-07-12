# Copyright (c) [2017-2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "y2storage/proposal/devices_planner_strategies/base"

module Y2Storage
  module Proposal
    module DevicesPlannerStrategies
      # Class to generate the list of planned devices of a proposal when
      # the format of propsal settings is ng.
      class Ng < Base
        # List of devices (read: partitions or volumes) that need to be
        # created to satisfy the settings.
        #
        # @see Base#planned_devices
        #
        # @param target [Symbol] :desired, :min
        # @return [Array<Planned::Device>]
        def planned_devices(target)
          @target = target
          proposed_volumes = settings.volumes.select(&:proposed?)

          planned_devices = proposed_volumes.map { |v| planned_device(v) }
          planned_devices = planned_boot_devices(planned_devices) + planned_devices

          remove_shadowed_subvolumes(planned_devices)
        end

        protected

        # Plans a device based on a <volume> section from control file
        #
        # @param volume [VolumeSpecification]
        # @return [Planned::device]
        def planned_device(volume)
          if settings.separate_vgs && volume.separate_vg?
            planned_separate_vg(volume)
          else
            planned_blk_device(volume)
          end
        end

        # @see #planned_device
        #
        # @param volume [VolumeSpecification]
        # @return [Planned::LvmLv, Planed::Partition]
        def planned_blk_device(volume)
          planned_type = settings.lvm ? Planned::LvmLv : Planned::Partition
          planned_device = planned_type.new(volume.mount_point, volume.fs_type)
          adjust_to_settings(planned_device, volume)
          planned_device
        end

        # @see #planned_device
        #
        # @param volume [VolumeSpecification]
        # @return [Planned::LvmVg]
        def planned_separate_vg(volume)
          lv = Planned::LvmLv.new(volume.mount_point, volume.fs_type)
          adjust_to_settings(lv, volume)

          planned_device = Planned::LvmVg.new(volume_group_name: volume.separate_vg_name, lvs: [lv])
          planned_device.pvs_encryption_password = settings.encryption_password
          planned_device
        end

        # Adjusts planned device values according to settings
        #
        # @note planned_device is modified
        #
        # @param planned_device [Planned::Device]
        # @param volume [VolumeSpecification]
        def adjust_to_settings(planned_device, volume)
          adjust_weight(planned_device, volume)
          adjust_encryption(planned_device, volume)
          adjust_sizes(planned_device, volume)
          adjust_btrfs(planned_device, volume)
          adjust_device(planned_device, volume)

          adjust_swap(planned_device, volume) if planned_device.swap?
        end

        # Adjusts planned device weight according to settings
        #
        # @param planned_device [Planned::Device]
        # @param volume [VolumeSpecification]
        def adjust_weight(planned_device, volume)
          planned_device.weight = value_with_fallbacks(volume, :weight)
        end

        # Adjusts planned device encryption according to settings
        #
        # @param planned_device [Planned::Device]
        # @param _volume [VolumeSpecification]
        def adjust_encryption(planned_device, _volume)
          return unless planned_device.is_a?(Planned::Partition)

          planned_device.encryption_password = settings.encryption_password
        end

        # Adjusts planned device sizes according to settings
        #
        # @param planned_device [Planned::Device]
        # @param volume [VolumeSpecification]
        def adjust_sizes(planned_device, volume)
          min_size = value_with_fallbacks(volume, :min_size)
          desired_size = value_with_fallbacks(volume, :desired_size)
          max_size = value_with_fallbacks(volume, :max_size)
          max_size_lvm = value_with_fallbacks(volume, :max_size_lvm)

          max_size = max_size_lvm if settings.lvm && max_size_lvm > DiskSize.zero
          planned_device.max_size = max_size

          min_size = (target == :min) ? min_size : desired_size
          planned_device.min_size = min_size

          if volume.adjust_by_ram?
            planned_device.min_size = [planned_device.min_size, ram_size].max
            planned_device.max_size = [planned_device.max_size, ram_size].max
          end

          nil
        end

        # Adjusts btrfs values according to settings
        #
        # @param planned_device [Planned::Device]
        # @param volume [VolumeSpecification]
        def adjust_btrfs(planned_device, volume)
          return unless planned_device.btrfs?

          planned_device.default_subvolume = volume.btrfs_default_subvolume || ""
          planned_device.subvolumes = volume.subvolumes
          planned_device.snapshots = volume.snapshots
          planned_device.read_only = volume.btrfs_read_only?

          adjust_btrfs_sizes(planned_device, volume) if planned_device.snapshots?
        end

        # Adjusts sizes when using snapshots
        #
        # @param planned_device [Planned::Device]
        # @param volume [VolumeSpecification]
        def adjust_btrfs_sizes(planned_device, volume)
          if volume.snapshots_size > DiskSize.zero
            planned_device.min_size += volume.snapshots_size
            planned_device.max_size += volume.snapshots_size
          elsif volume.snapshots_percentage > 0
            multiplicator = 1.0 + volume.snapshots_percentage / 100.0
            planned_device.min_size *= multiplicator
            planned_device.max_size *= multiplicator
          end
        end

        # Adjusts the disk restrictions according to settings
        #
        # @param planned_device [Planned::Device]
        # @param volume [VolumeSpecification]
        def adjust_device(planned_device, volume)
          if settings.allocate_mode?(:device)
            planned_device.disk = volume.device if planned_device.respond_to?(:disk=)
          elsif planned_device.root?
            # Forcing this when planned_device is a LV would imply the new VG
            # can only be located in that disk (preventing it to spread over
            # several disks). We likely don't want that.
            planned_device.disk = settings.root_device if planned_device.is_a?(Planned::Partition)
          end
        end

        # Adjusts values when planned device is swap
        #
        # @param planned_device [Planned::Device]
        # @param _volume [VolumeSpecification]
        def adjust_swap(planned_device, _volume)
          if planned_device.is_a?(Planned::Partition)
            reuse = reusable_swap(planned_device.min_size)
            if reuse
              planned_device.reuse_name = reuse.name
              log.info "planned to reuse swap #{reuse.name}"
            end
          else
            planned_device.logical_volume_name = "swap"
          end
        end

        # Calculates the value for a specific attribute taking into
        # account the fallback values
        #
        # @param volume [VolumeSpecification]
        # @param attr [Symbol, String]
        def value_with_fallbacks(volume, attr)
          value = volume.send(attr)

          volumes = volumes_with_fallback(volume.mount_point, attr)
          return value if volumes.empty?

          volumes.inject(value) { |total, v| total + v.send(attr) }
        end

        # Searches for volume specifications that have fallback value
        # for a specific mount point
        #
        # @param mount_point [String]
        # @param attr [Symbol, String]
        #
        # @return [Array<VolumeSpecification>]
        def volumes_with_fallback(mount_point, attr)
          not_proposed_volumes.select { |v| v.send("fallback_for_#{attr}") == mount_point }
        end

        # Searches for not proposed volume specifications
        # @return [Array<VolumeSpecification>]
        def not_proposed_volumes
          settings.volumes.reject(&:proposed?)
        end
      end
    end
  end
end
