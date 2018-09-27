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

require "cwm/widget"
require "y2partitioner/icons"
require "y2partitioner/widgets/bcache_device_description"
require "y2partitioner/widgets/disk_device_description"
require "y2partitioner/widgets/used_devices_tab"
require "y2partitioner/widgets/partitions_tab"
require "y2partitioner/widgets/blk_device_edit_button"
require "y2partitioner/widgets/partition_table_add_button"
require "y2partitioner/widgets/partition_table_clone_button"

module Y2Partitioner
  module Widgets
    module Pages
      # Page for a disk device (Disk, Dasd, BIOS RAID, Multipath or Bcache).
      #
      # This page contains a {DiskTab} and a {PartitionsTab}. In case of Multipath
      # or BIOS RAID, it also contains a {UsedDevicesTab}.
      class Disk < CWM::Page
        # @return [Y2Storage::BlkDevice] Disk device this page is about
        attr_reader :disk
        alias_method :device, :disk

        # Constructor
        #
        # @param disk [Y2Storage::Disk, Y2Storage::Dasd, Y2Storage::DmRaid,
        #              Y2Storage::MdMember, Y2Storage::Multipath, Y2Storage::Bcache]
        # @param pager [CWM::TreePager]
        def initialize(disk, pager)
          textdomain "storage"

          @disk = disk
          @pager = pager
          self.widget_id = "disk:" + disk.name
        end

        # @macro seeAbstractWidget
        def label
          disk.basename
        end

        # @macro seeCustomWidget
        def contents
          icon = Icons.small_icon(Icons::HD)
          VBox(
            Left(
              HBox(
                Image(icon, ""),
                # TRANSLATORS: Heading. String followed by device name of hard disk
                Heading(format(_("Hard Disk: %s"), disk.name))
              )
            ),
            tabs
          )
        end

      private

        # Tabs to show device data
        #
        # In general, two tabs are presented: one for the device info and
        # another one with the device partitions. When the device is a  BIOS RAID or
        # Multipath, a third tab is used to show the disks that belong to the device.
        #
        # @return [Tabs]
        def tabs
          tabs = [
            DiskTab.new(disk),
            PartitionsTab.new(disk, @pager)
          ]

          tabs << UsedDevicesTab.new(used_devices, @pager) if used_devices_tab?

          Tabs.new(*tabs)
        end

        # Whether a extra tab for used devices is necessary
        #
        # @return [Boolean]
        def used_devices_tab?
          disk.is?(:multipath, :dm_raid, :md)
        end

        # Devices used by the RAID or Multipath
        #
        # @return [Array<BlkDevice>]
        def used_devices
          if disk.is?(:multipath, :dm_raid)
            disk.parents
          elsif disk.is?(:md)
            disk.devices
          else
            []
          end
        end
      end

      # A Tab for disk device description
      class DiskTab < CWM::Tab
        # Constructor
        #
        # @param disk [Y2Storage::BlkDevice]
        def initialize(disk, initial: false)
          textdomain "storage"

          @disk = disk
          @initial = initial
        end

        # @macro seeAbstractWidget
        def label
          _("&Overview")
        end

        # @macro seeCustomWidget
        def contents
          # Page wants a WidgetTerm, not an AbstractWidget
          @contents ||= VBox(
            description,
            Left(
              HBox(
                PartitionTableAddButton.new(device: @disk),
                PartitionTableCloneButton.new(device: @disk)
              )
            )
          )
        end

      private

        def description
          case @disk
          when Y2Storage::Bcache
            BcacheDeviceDescription.new(@disk)
          else
            DiskDeviceDescription.new(@disk)
          end
        end
      end
    end
  end
end
