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

require "yast"
require "y2storage"
require "y2partitioner/device_graphs"

module Y2Partitioner
  module Actions
    module Controllers
      # This class stores information about an LVM volume group being created and
      # takes care of updating the devicegraph when needed
      class LvmVg
        include Yast::I18n

        # @return [String] given volume group name
        attr_accessor :vg_name

        # @return [Y2Storage::DiskSize] given extent size
        attr_reader :extent_size

        # @return [Y2Storage::LvmVg] new created volume group
        attr_reader :vg

        DEFAULT_VG_NAME = "".freeze
        DEFAULT_EXTENT_SIZE = Y2Storage::DiskSize.MiB(4).freeze

        ALLOWED_NAME_CHARS =
          "0123456789" \
          "abcdefghijklmnopqrstuvwxyz" \
          "ABCDEFGHIJKLMNOPQRSTUVWXYZ" \
          "._-+".freeze

        # Constructor
        #
        # @note This will create a new LVM volume group in the devicegraph right away.
        # @see #initialize_values
        def initialize
          textdomain "storage"

          initialize_values
        end

        # Stores the given extent size
        # @note The value is internally stored as DiskSize (see {to_size}) when it can
        #   be parsed; nil otherwise.
        #
        # @param value [String]
        def extent_size=(value)
          @extent_size = to_size(value)
        end

        # Effective size of the resulting LVM volume group
        #
        # @return [Y2Storage::DiskSize]
        def vg_size
          vg.size
        end

        # Applies given values (i.e., volume group name and extent size) to the
        # volume group
        def apply_values
          vg.vg_name = vg_name
          vg.extent_size = extent_size
        end

        # Error messages for the volume group name
        #
        # @note When there is no error, an empty list is returned.
        #
        # @return [Array<String>] list of errors
        def vg_name_errors
          errors = []
          errors << empty_vg_name_message if empty_vg_name?
          errors << illegal_vg_name_message if vg_name && illegal_vg_name?
          errors << duplicated_vg_name_message if vg_name && duplicated_vg_name?
          errors
        end

        # Error messages for the extent size
        #
        # @note When there is no error, an empty list is returned.
        #
        # @return [Array<String>] list of errors
        def extent_size_errors
          errors = []
          errors << invalid_extent_size_message if invalid_extent_size?
          errors
        end

        # Devices that can be selected to become physical volume of a volume group
        #
        # @note A physical volume could be created using a partition, disk, multipath,
        #   DM Raid or MD Raid. Dasd devices cannot be used.
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def available_devices
          devices =
            working_graph.disks +
            working_graph.multipaths +
            working_graph.dm_raids +
            working_graph.md_raids +
            working_graph.partitions

          devices.flatten.compact.select { |d| available?(d) }
        end

        # Devices that are already used as physical volume by the volume group
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def devices_in_vg
          vg.lvm_pvs.map(&:plain_blk_device)
        end

        # Adds a device as physical volume of the volume group
        #
        # It removes any previous children (like filesystems) from the device and
        # adapts the partition id if possible.
        #
        # @raise [ArgumentError] if the device is already an physcial volume of the
        #   volume group.
        #
        # @param device [Y2Storage::BlkDevice]
        def add_device(device)
          if devices_in_vg.include?(device)
            raise ArgumentError,
              "The device #{device} is already a physical volume of the volume group #{vg_name}"
          end

          # TODO: save the current status and descendants of the device,
          # in case the device is removed from the volume group during this
          # execution of the partitioner.
          device.adapted_id = Y2Storage::PartitionId::LVM if device.is?(:partition)
          device.remove_descendants
          vg.add_lvm_pv(device)
        end

        # Removes a device from the physical volumes of the volume group
        #
        # @raise [ArgumentError] if the device is not a physical volume of the volume group
        #
        # @param device [Y2Storage::BlkDevice]
        def remove_device(device)
          if !devices_in_vg.include?(device)
            raise ArgumentError,
              "The device #{device} is not used as physical volumen by the volume group #{vg_name}"
          end

          # TODO: restore status and descendants of the device when it makes sense
          vg.remove_lvm_pv(device)
        end

      private

        # Current devicegraph
        #
        # @return [Y2Storage::Devicegraph]
        def working_graph
          DeviceGraphs.instance.current
        end

        # Sets initial values
        #
        # @note A default volume group name and extent size is assigned, and a new volume
        # group is created.
        def initialize_values
          @vg_name = DEFAULT_VG_NAME
          @extent_size = DEFAULT_EXTENT_SIZE
          @vg = Y2Storage::LvmVg.create(working_graph, vg_name)
        end

        # Checks whether the given volume group name is empty
        #
        # @return [Boolean] true if volume group name is "" or nil; false otherwise
        def empty_vg_name?
          vg_name.nil? || vg_name.empty?
        end

        # Error message to show when the given volume group name is empty
        #
        # @return [String]
        def empty_vg_name_message
          _("Enter a name for the volume group.")
        end

        # Checks whether the given volume group name has illegal characters
        #
        # @see ALLOWED_NAME_CHARS
        #
        # @return [Boolean] true if volume group name has illegal characters;
        #   false otherwise
        def illegal_vg_name?
          vg_name.split(//).any? { |c| !ALLOWED_NAME_CHARS.include?(c) }
        end

        # Error message to show when the given volume group name contains illegal
        # characters
        #
        # @return [String]
        def illegal_vg_name_message
          _("The name for the volume group contains illegal characters. Allowed\n" \
            "are alphanumeric characters, \".\", \"_\", \"-\" and \"+\"")
        end

        # Checks whether it exists another device with the given volume group name
        #
        # @return [Boolean] true if there is another device with the same name;
        #   false otherwise
        def duplicated_vg_name?
          # libstorage has the logic to generate a volume group name, so the name could
          # assigned to the volume group, then check the duplicity of the name and restore
          # previous name if the given one is duplicated. Instead of that, the logic to
          # generate the volume group name has been duplicated here due to its simplicity.
          name = File.join("/dev", vg_name)
          Y2Storage::BlkDevice.all(working_graph).map(&:name).include?(name)
        end

        # Error message to show when the given volume group name is duplicated
        #
        # @return [String]
        def duplicated_vg_name_message
          # TRANSLATORS: vg_name is replaced by the name of the volume group
          format(
            _("The volume group name \"%{vg_name}\" conflicts\n" \
              "with another entry in the /dev directory."),
            vg_name: vg_name
          )
        end

        # Checks whether the given extent size is not valid
        #
        # @note Extent size is valid if it is bigger than 1 KiB, multiple of 128 KiB
        #   and power of 2.
        #
        # @return [Boolean] true if the extent size is not valid; false otherwise
        def invalid_extent_size?
          !(extent_size &&
            extent_size > Y2Storage::DiskSize.KiB(1) &&
            extent_size % Y2Storage::DiskSize.KiB(128) == Y2Storage::DiskSize.zero &&
            extent_size.power_of?(2))
        end

        # Error message to show when the given extent size is not valid
        #
        # @see #invalid_extent_size?
        #
        # @return [String]
        def invalid_extent_size_message
          _("The data entered in invalid. Insert a physical extent size larger than 1 KiB\n" \
            "in powers of 2 and multiple of 128 KiB, for example, \"512 KiB\" or \"4 MiB\"")
        end

        # Checks whether a device is availabe to be used as physical volume
        #
        # @return [Boolean] true if the device is available; false otherwise
        def available?(device)
          if device.is?(:partition)
            available_partition?(device)
          else
            available_disk?(device)
          end
        end

        # Checks whether a partition is available to be used as physical volume
        #
        # @note A partition is available when its id is linux, lvm, swap or raid,
        #   it is not formatted and it does not belong to another device (raid or
        #   volume group). A partition is also available when it is formated but
        #   not mounted.
        #
        # @return [Boolean] true if the partition is available; false otherwise
        def available_partition?(partition)
          return false unless partition.id.is?(:linux_system)
          can_be_used?(partition)
        end

        # Checks whether a device is available to be used as physical volume
        #
        # @note A device is available when it has not partitions and it is not
        #   formatted and it does not belong to another device (raid or volume
        #   group). A device is also available when it is formated but not mounted.
        #
        # @return [Boolean] true if the device is available; false otherwise
        def available_disk?(disk)
          partition_table = disk.partition_table
          partition_table ? partition_table.partitions.empty? : can_be_used?(disk)
        end

        # Checks whether a device can be used
        #
        # @note A device can be used when it is not formatted and it is not used by
        #   another device (raid or volume group) or it is formatted but not mounted.
        #
        # @return [Boolean] true if the device can be used; false otherwise
        def can_be_used?(device)
          !used?(device) || (formatted?(device) && !mounted?(device))
        end

        # Checks whether a device is already used.
        #
        # @note A device is used when it is formatted or belongs to another
        #   device (raid or volume group). A device is not considered as used
        #   when it is only encrypted.
        #
        # @return [Boolean] true if the device is used; false otherwise
        def used?(device)
          descendants = device.descendants
          return false if descendants.empty?
          return false if descendants.size == 1 && device.encrypted?

          true
        end

        # Checks whether a device is mounted
        #
        # @return [Boolean] true if it is mounted; false otherwise
        def mounted?(device)
          return false unless formatted?(device)

          mount_point = device.filesystem.mount_point
          mount_point && !mount_point.empty?
        end

        # Checks whether a device is formatted
        #
        # @return [Boolean] true if it is formatted; false otherwise
        def formatted?(device)
          !device.filesystem.nil?
        end

        # Converts a string to DiskSize, returning nil if the conversion
        # it is not possible
        #
        # @see Y2Storage::DiskSize#from_human_string
        #
        # @return [Y2Storage::DiskSize, nil]
        def to_size(value)
          return nil if value.nil?
          Y2Storage::DiskSize.from_human_string(value)
        rescue TypeError
          nil
        end
      end
    end
  end
end
