# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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
          planned_type = settings.lvm ? Planned::LvmLv : Planned::Partition
          planned_device = planned_type.new(volume.mount_point, volume.fs_type)

          adjust_to_settings(planned_device, volume)

          planned_device
        end

        # Adjusts planned device values according to settings
        #
        # @param planned_device [Planned::Device]
        # @param volume [VolumeSpecification]
        def adjust_to_settings(planned_device, volume)
          planned_device.weight = volume.weight

          if planned_device.is_a?(Planned::Partition)
            planned_device.encryption_password = settings.encryption_password
          end

          adjust_sizes(planned_device, volume)
          adjust_btrfs(planned_device, volume)

          adjust_root(planned_device, volume) if planned_device.root?
          adjust_swap(planned_device, volume) if planned_device.swap?
        end

        # Adjusts planned device sizes according to settings
        #
        # @param planned_device [Planned::Device]
        # @param volume [VolumeSpecification]
        def adjust_sizes(planned_device, volume)
          max_size = volume.max_size
          max_size = volume.max_size_lvm if settings.lvm && volume.max_size_lvm
          planned_device.max_size = max_size

          min_size = target == :min ? volume.min_size : volume.desired_size
          planned_device.min_size = min_size

          if volume.adjust_by_ram?
            min_size = [planned_device.min_size, ram_size].max
            planned_device.min_size = min_size

            max_size = [planned_device.max_size, ram_size].max
            planned_device.max_size = max_size
          end
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

          adjust_btrfs_sizes(planned_device, volume) if planned_device.snapshots?
        end

        # Adjusts sizes when using snapshots
        #
        # @param planned_device [Planned::Device]
        # @param volume [VolumeSpecification]
        def adjust_btrfs_sizes(planned_device, volume)
          return if volume.snapshots_size.nil?

          case volume.snapshots_size
          when DiskSize
            planned_device.min_size += volume.snapshots_size
            planned_device.max_size += volume.snapshots_size
          when Integer
            multiplicator = 1.0 + volume.snapshots_size / 100.0
            planned_device.min_size *= multiplicator
            planned_device.max_size *= multiplicator
          end
        end

        # Adjusts values when planned device is root
        #
        # @param planned_device [Planned::Device]
        # @param volume [VolumeSpecification]
        def adjust_root(planned_device, _volume)
          planned_device.disk = settings.root_device if planned_device.is_a?(Planned::Partition)
        end

        # Adjusts values when planned device is swap
        #
        # @param planned_device [Planned::Device]
        # @param volume [VolumeSpecification]
        def adjust_swap(planned_device, _volume)
          if planned_device.is_a?(Planned::Partition)
            reuse = reusable_swap(planned_device.min_size)
            planned_device.reuse = reuse.name if reuse
          else
            planned_device.logical_volume_name = "swap"
          end
        end
      end
    end
  end
end
