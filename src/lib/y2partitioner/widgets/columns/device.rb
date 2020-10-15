# Copyright (c) [2020] SUSE LLC
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
require "y2partitioner/widgets/columns/base"

module Y2Partitioner
  module Widgets
    module Columns
      # Widget for displaying the `Device` column, usually the physical name of a block device
      class Device < Base
        # Constructor
        def initialize
          textdomain "storage"
        end

        # @see Columns::Base#title
        def title
          # TRANSLATORS: table header, Device is physical name of block device, e.g. "/dev/sda1"
          _("Device")
        end

        # @see Columns::Base#entry_value
        def entry_value(entry)
          value_for(entry.device, entry: entry)
        end

        # @see Columns::Base#value_for
        def value_for(device, entry: nil)
          cell(
            device_name(device, entry),
            sort_key_for(device)
          )
        end

        private

        # The device name
        #
        # @return [String]
        def device_name(device, entry)
          return fstab_device_name(device, entry) if fstab_entry?(device)
          return blk_device_name(device, entry) unless device.is?(:blk_filesystem)
          return device.type.to_human_string unless device.multidevice?

          format(
            # TRANSLATORS: fs_type is the filesystem type. I.e., BtrFS
            #              device_name is the base name of the block device. I.e., sda or sda1...
            _("%{fs_type} %{device_name}"),
            fs_type:     device.type.to_human_string,
            device_name: device.blk_device_basename
          )
        end

        # @see #device_name
        #
        # @return [String]
        def blk_device_name(device, entry)
          return device.basename if short_name?(entry)

          device.display_name
        end

        # Whether a short name should be used to display the given entry
        #
        # @param entry [DeviceTableEntry, nil]
        # @return [Boolean]
        def short_name?(entry)
          return false unless entry
          return false if entry.full_name?
          return false unless entry.device.is_a?(Y2Storage::Device)

          entry.device.is?(:partition, :lvm_lv)
        end

        # The name for the device in the given fstab entry
        #
        # @param fstab_entry [Y2Storage::SimpleEtcFstabEntry]
        # @param table_entry [DeviceTableEntry, nil]
        # @return [String] the #device_name if it is found in the system; the fstab_device otherwise
        def fstab_device_name(fstab_entry, table_entry)
          device = fstab_entry.device(system_graph)
          device ? device_name(device, table_entry) : fstab_entry.fstab_device
        end

        # A sort key for the given device
        #
        # @param device [Y2Storage::Device, Y2Storage::SimpleEtcFstabEntry]
        # @return [String, nil] the Y2Storage::Device#name_sort key unless device is a fstab entry
        #                       or a filesystem; nil otherwise
        def sort_key_for(device)
          return nil if fstab_entry?(device)
          return nil if device.is?(:blk_filesystem)

          sort_key(device.name_sort_key)
        end
      end
    end
  end
end
