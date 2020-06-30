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
        # @see Columns::Base#title
        def title
          # TRANSLATORS: table header, Device is physical name of block device, e.g. "/dev/sda1"
          _("Device")
        end

        # @see Columns::Base#value_for
        def value_for(device)
          cell(
            device_name(device),
            sort_key_for(device)
          )
        end

        private

        # The device name
        #
        # @return [String]
        def device_name(device)
          return fstab_device_name(device) if fstab_entry?(device)
          return device.display_name unless device.is?(:blk_filesystem)
          return device.type.to_human_string unless device.multidevice?

          format(
            # TRANSLATORS: fs_type is the filesystem type. I.e., BtrFS
            #              device_name is the base name of the block device. I.e., sda or sda1...
            _("%{fs_type} %{device_name}"),
            fs_type:     device.type.to_human_string,
            device_name: device.blk_device_basename
          )
        end

        # The name for the device in the given fstab entry
        #
        # @param fstab_entry [Y2Storage::SimpleEtcFstabEntry]
        # @return [String] the #device_name if it is found in the system; the fstab_device otherwise
        def fstab_device_name(fstab_entry)
          device = fstab_entry.device(system_graph)
          device ? device_name(device) : fstab_entry.fstab_device
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
