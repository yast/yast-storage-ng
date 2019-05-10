# encoding: utf-8

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

require "yast"
require "y2storage"
require "y2partitioner/device_graphs"
require "y2partitioner/size_parser"
require "y2partitioner/ui_state"
require "y2partitioner/blk_device_restorer"
require "y2partitioner/actions/controllers/available_devices"

module Y2Partitioner
  module Actions
    module Controllers
      # This class stores information about an LVM volume group being created or
      # modified and takes care of updating the devicegraph when needed.
      class LvmVg
        include Yast::I18n

        include SizeParser

        include AvailableDevices

        # @return [String] given volume group name
        attr_accessor :vg_name

        # @return [Y2Storage::DiskSize] given extent size
        attr_reader :extent_size

        # @return [Y2Storage::LvmVg] volume group to work over
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
        # @note When the volume group is not given, a new LvmVg object will be created in
        #   the devicegraph right away.
        #
        # @see #initialize_action
        #
        # @param vg [Y2Storage::LvmVg] a volume group to be modified
        def initialize(vg: nil)
          textdomain "storage"

          initialize_action(vg)
        end

        # Title to display in the dialogs during the process
        #
        # @note The returned title depends on the action to perform (see {#initialize_action})
        #
        # @return [String]
        def wizard_title
          case action
          when :add
            # TRANSLATORS: dialog title when creating an LVM volume group
            _("Add Volume Group")
          when :resize
            # TRANSLATORS: dialog title when resizing an LVM volume group, where %s is replaced
            # by a device name (e.g., /dev/vg0)
            _("Resize Volume Group %s") % vg.name
          end
        end

        # Stores the given extent size
        # @note The value is internally stored as DiskSize when it can be parsed;
        #   nil otherwise.
        #
        # @param value [String]
        def extent_size=(value)
          @extent_size = parse_user_size(value)
        end

        # Effective size of the resulting LVM volume group
        #
        # @return [Y2Storage::DiskSize]
        def vg_size
          vg.size
        end

        # Size of the logical volumes belonging to the current volume group
        #
        # @return [Y2Storage::DiskSize]
        def lvs_size
          Y2Storage::DiskSize.sum(vg.lvm_lvs.map(&:size))
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
          super(working_graph) { |d| valid_device?(d) }
        end

        # Devices that are already used as physical volume by the volume group
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def devices_in_vg
          vg.lvm_pvs.map(&:plain_blk_device)
        end

        # Devices used by committed physical volumes of the current volume group
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def committed_devices
          return [] unless probed_vg?

          probed_vg.lvm_pvs.map(&:plain_blk_device)
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

          device.adapted_id = Y2Storage::PartitionId::LVM if device.is?(:partition)
          device = device.encryption if device.encryption
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

          device = device.encryption if device.encryption
          vg.remove_lvm_pv(device)
          BlkDeviceRestorer.new(device.plain_device).restore_from_checkpoint
        end

      private

        # Current action to perform
        # @return [Symbol] :add, :resize
        attr_reader :action

        # Sets the action to perform and initializes necessary data
        #
        # @param current_vg [Y2Storage::LvmVg, nil] nil if the volume group is
        #   going to be created.
        def initialize_action(current_vg)
          detect_action(current_vg)

          case action
          when :add
            initialize_for_add
          when :resize
            initialize_for_resize(current_vg)
          end

          UIState.instance.select_row(vg) unless vg.nil?
        end

        # Detects current action
        #
        # @note When no volume group is given, the action is set to :add. Otherwise,
        #   the action is set to :resize.
        def detect_action(vg)
          # A volume group is given when it is going to be resized
          @action = vg.nil? ? :add : :resize
        end

        # Initializes internal values for add action
        def initialize_for_add
          @vg = create_vg
          @extent_size = DEFAULT_EXTENT_SIZE
          @vg_name = DEFAULT_VG_NAME
        end

        # Initializes internal values for resize action
        def initialize_for_resize(vg)
          @vg = vg
        end

        # Current devicegraph
        #
        # @return [Y2Storage::Devicegraph]
        def working_graph
          DeviceGraphs.instance.current
        end

        # Creates a new volume group
        #
        # @return [Y2Storage::LvmVg]
        def create_vg
          Y2Storage::LvmVg.create(working_graph, "")
        end

        # Probed version of the current volume group
        #
        # @note It returns nil if the volume group does not exist in probed devicegraph.
        #
        # @return [Y2Storage::LvmVg, nil]
        def probed_vg
          system = Y2Partitioner::DeviceGraphs.instance.system
          system.find_device(vg.sid)
        end

        # Whether the current volume group exists in the probed devicegraph
        #
        # @return [Boolean] true if the volume group exists in probed; false otherwise.
        def probed_vg?
          !probed_vg.nil?
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
          !working_graph.find_by_name(name).nil?
        end

        # Error message to show when the given volume group name is duplicated
        #
        # @return [String]
        def duplicated_vg_name_message
          # TRANSLATORS: %{vg_name} is replaced by the name of the volume group
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
          _("The data entered is invalid. Insert a physical extent size larger than 1 KiB\n" \
            "in powers of 2 and multiple of 128 KiB, for example, \"512 KiB\" or \"4 MiB\"")
        end

        # Checks whether an available device can be used as physical volume
        #
        # @param device [Y2Storage::BlkDevice]
        # @return [Boolean]
        def valid_device?(device)
          if device.is?(:partition)
            valid_partition_for_vg?(device)
          else
            valid_device_for_vg?(device)
          end
        end

        # Checks whether an available partition can be used as physical volume
        #
        # The partition can be used if its id is linux, lvm, swap or raid.
        #
        # @param partition [Y2Storage::Partition]
        # @return [Boolean]
        def valid_partition_for_vg?(partition)
          partition.id.is?(:linux_system)
        end

        # Checks whether an available device can be used as physical volume
        #
        # The device can be used if its has a proper type.
        #
        # @param device [Y2Storage::BlkDevice]
        # @return [Boolean]
        def valid_device_for_vg?(device)
          device.is?(:disk, :multipath, :bios_raid, :md)
        end
      end
    end
  end
end
