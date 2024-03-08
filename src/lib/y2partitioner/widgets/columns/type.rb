# Copyright (c) [2020-2024] SUSE LLC
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
require "y2partitioner/icons"
require "y2partitioner/widgets/columns/base"
require "y2storage/device_description"

module Y2Partitioner
  module Widgets
    module Columns
      # Widget for displaying the `Type` column, which actually is a kind of device description
      class Type < Base
        # Device icons based on its type
        #
        # @see #icon
        DEVICE_ICONS = {
          bcache:          Icons::BCACHE,
          disk:            Icons::HD,
          dasd:            Icons::HD,
          multipath:       Icons::MULTIPATH,
          nfs:             Icons::NFS,
          partition:       Icons::HD_PART,
          raid:            Icons::RAID,
          lvm_vg:          Icons::LVM,
          lvm_lv:          Icons::LVM_LV,
          btrfs:           Icons::BTRFS,
          btrfs_subvolume: Icons::BTRFS,
          tmpfs:           Icons::TMPFS
        }
        private_constant :DEVICE_ICONS

        # Constructor
        def initialize
          super
          textdomain "storage"
        end

        # @see Columns::Base#title
        def title
          # TRANSLATORS: table header, type of disk or partition. Can be longer. E.g. "Linux swap"
          _("Type")
        end

        # @see Columns::Base#value_for
        def value_for(device)
          cell(
            Icon(device_icon(device)),
            device_label(device)
          )
        end

        private

        # The icon name for the device type
        #
        # @see DEVICE_ICONS
        #
        # @param device [Y2Storage::Device, Y2Storage::LvmPv, Y2Storage::SimpleEtcFstabEntry]
        # @return [String]
        def device_icon(device)
          return fstab_device_icon(device) if fstab_entry?(device)
          return lvm_pv_icon(device) if device.is?(:lvm_pv)

          type = DEVICE_ICONS.keys.find { |k| device.is?(k) }
          type ? DEVICE_ICONS[type] : Icons::DEFAULT_DEVICE
        end

        # The icon for the device of an LVM physical volume
        #
        # @param lvm_pv [Y2Storage::LvmPv]
        # @return [String] the #device_icon if device is found in the system; empty string otherwise
        def lvm_pv_icon(lvm_pv)
          device_icon(lvm_pv.plain_blk_device)
        end

        # The icon for the device in the given fstab entry
        #
        # @param fstab_entry [Y2Storage::SimpleEtcFstabEntry]
        # @return [String] the #device_icon if device is found in the system; empty string otherwise
        def fstab_device_icon(fstab_entry)
          device = fstab_entry.device(system_graph)
          device ? device_icon(device) : ""
        end

        # A text describing the given device
        #
        # @see DeviceDescription
        #
        # @param device [Y2Storage::Device, Y2Storage::LvmPv, Y2Storage::SimpleEtcFstabEntry]
        # @return [String]
        def device_label(device)
          Y2Storage::DeviceDescription.new(device, system_graph: system_graph).to_s
        end
      end
    end
  end
end
