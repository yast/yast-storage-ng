# Copyright (c) [2016-2021] SUSE LLC
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

require "y2storage/storage_manager"
require "y2storage/planned"
require "y2storage/disk_size"
require "y2storage/boot_requirements_checker"
require "y2storage/exceptions"

module Y2Storage
  module Proposal
    # Class to generate the list of planned devices of a proposal.
    class DevicesPlanner
      include Yast::Logger

      # Settings used to calculate the planned devices
      # @return [ProposalSettings]
      attr_accessor :settings

      # Constructor
      #
      # @param settings [ProposalSettings]
      # @param devicegraph [Devicegraph]
      def initialize(settings, devicegraph)
        @settings = settings
        @devicegraph = devicegraph
      end

      # List of devices (read: partitions or volumes) that need to be
      # created to satisfy the settings.
      #
      # @param target [Symbol] :desired means the sizes of the planned devices
      #   should be the ideal ones, :min for generating the smallest functional
      #   devices
      # @return [Array<Planned::Device>]
      def planned_devices(target)
        @target = target
        proposed_volumes = settings.volumes.select(&:proposed?)

        planned_devices = proposed_volumes.map { |v| planned_device(v) }
        planned_devices = planned_boot_devices(planned_devices) + planned_devices

        remove_shadowed_subvolumes(planned_devices)
      end

      protected

      # @return [Devicegraph]
      attr_reader :devicegraph

      # @return [Symbol] :desired or :min
      attr_reader :target

      # Planned devices needed by the bootloader
      #
      # @param planned_devices [Array<Planned::Device>] devices that have been planned
      # @return [Array<Planned::Device>]
      def planned_boot_devices(planned_devices)
        flat = planned_devices.flat_map do |dev|
          dev.respond_to?(:lvs) ? dev.lvs : dev
        end
        checker = BootRequirementsChecker.new(
          devicegraph, planned_devices: flat, boot_disk_name: settings.root_device
        )
        checker.needed_partitions(target)
      rescue BootRequirementsChecker::Error => e
        # As documented, {BootRequirementsChecker#needed_partition} raises this
        # exception if it's impossible to get a bootable system, even adding
        # more partitions.
        raise NotBootableError, e.message
      end

      # Swap partition that can be reused.
      #
      # It returns the smaller partition that is big enough for our purposes.
      #
      # @param required_size [DiskSize]
      # @return [Partition]
      def reusable_swap(required_size)
        return nil if settings.use_lvm || settings.use_encryption

        partitions = available_swap_partitions
        partitions.select! { |part| part.size >= required_size }
        # Use #name in case of #size tie to provide stable sorting
        partitions.min_by { |part| [part.size, part.name] }
      end

      # Returns all avaiable swap partitions
      #
      # @return [Array<Partition>]
      def available_swap_partitions
        devicegraph.partitions.select(&:swap?)
      end

      # Delete shadowed subvolumes from each planned device
      # @param planned_devices [Array<Planned::Device>] devices that have been planned
      def remove_shadowed_subvolumes(planned_devices)
        planned_devices.each do |device|
          next unless device.respond_to?(:subvolumes)

          device.shadowed_subvolumes(planned_devices).each do |subvolume|
            log.info "Subvolume #{subvolume} would be shadowed. Removing it."
            device.subvolumes.delete(subvolume)
          end
        end
      end

      # Return the total amount of RAM as DiskSize
      #
      # @return [DiskSize] current RAM size
      def ram_size
        DiskSize.new(StorageManager.instance.arch.ram_size)
      end

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
        planned_device.min_size = min_size(volume)
        planned_device.max_size = max_size(volume)

        if volume.adjust_by_ram?
          planned_device.min_size = [planned_device.min_size, ram_size].max
          planned_device.max_size = [planned_device.max_size, ram_size].max
        end

        nil
      end

      # Min size for the given volume, not having adjust_by_ram? into account
      #
      # @param volume [VolumeSpecification]
      # @return [DiskSize]
      def min_size(volume)
        if :min == target
          value_with_fallbacks(volume, :min_size)
        else
          value_with_fallbacks(volume, :desired_size)
        end
      end

      # Max size for the given volume, not having adjust_by_ram? into account
      #
      # @param volume [VolumeSpecification]
      # @return [DiskSize]
      def max_size(volume)
        # If no LVM is involved, this is quite straightforward
        return value_with_fallbacks(volume, :max_size) unless settings.lvm

        # But with LVM, the behavior of fallback_max_size_lvm is not so obvious.
        # From the existing tests, it can be inferred that such attribute only
        # looks into max_size_lvm (never falling back to max_size), so it
        # basically only makes sense when combined with an explicit max_size_lvm.
        value = value_with_fallbacks(volume, :max_size_lvm)

        # But for the current volume being calculated, it is expected to fallback to
        # max_size when there is no max_size_lvm
        value += volume.max_size if volume.max_size_lvm.zero?
        value
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
