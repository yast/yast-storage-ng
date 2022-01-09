# Copyright (c) [2017-2021] SUSE LLC
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

require "y2partitioner/widgets/pages/tabbed"
require "y2partitioner/widgets/used_devices_tab"
require "y2partitioner/widgets/overview_tab"

module Y2Partitioner
  module Widgets
    module Pages
      # Page for a disk device (Disk, Dasd, BIOS RAID or Multipath).
      #
      # This page contains an {OverviewTab} and, in case of Multipath or BIOS RAID,
      # also a {DiskUsedDevicesTab}.
      class Disk < Tabbed
        # @return [Y2Storage::BlkDevice] Disk device this page is about
        attr_reader :disk
        alias_method :device, :disk

        # Constructor
        #
        # @param disk [Y2Storage::Disk, Y2Storage::Dasd, Y2Storage::DmRaid,
        #              Y2Storage::MdMember, Y2Storage::Multipath]
        # @param pager [CWM::TreePager]
        def initialize(disk, pager)
          super()
          textdomain "storage"

          @disk = disk
          @pager = pager
          self.widget_id = "disk:" + disk.name
        end

        # @macro seeAbstractWidget
        def label
          disk.basename
        end

        private

        # Tabs to show device data
        #
        # In general, two tabs are presented: one for the device info and
        # another one with the device partitions. When the device is a  BIOS RAID or
        # Multipath, a third tab is used to show the disks that belong to the device.
        #
        # @return [Array<CWM::Tab>]
        def calculate_tabs
          tabs = [OverviewTab.new(disk, @pager)]
          tabs << DiskUsedDevicesTab.new(disk, @pager) if used_devices_tab?

          tabs
        end

        # Whether a extra tab for used devices is necessary
        #
        # @return [Boolean]
        def used_devices_tab?
          disk.is?(:multipath, :dm_raid, :md)
        end
      end

      # A Tab for the used devices of a Multipath or BIOS RAID
      class DiskUsedDevicesTab < UsedDevicesTab
        # @see UsedDevicesTab#used_devices
        def used_devices
          if device.is?(:multipath, :dm_raid)
            device.parents
          elsif device.is?(:md)
            device.devices
          else
            []
          end
        end
      end
    end
  end
end
