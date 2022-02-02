# Copyright (c) [2017-2022] SUSE LLC
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
require "y2partitioner/ui_state"
require "y2partitioner/widgets/pages/base"
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/widgets/device_buttons_set"
require "y2partitioner/widgets/columns"

Yast.import "Mode"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for all storage devices in the system
      class System < Base
        include Yast::I18n

        # Constructor
        #
        # @param [String] hostname of the system, to be displayed
        # @param pager [CWM::TreePager]
        def initialize(hostname, pager)
          super()
          textdomain "storage"

          @pager = pager
          @hostname = hostname
        end

        # @macro seeAbstractWidget
        def label
          # TRANSLATORS: label of the first element of the Partitioner left tree
          _("All Devices")
        end

        # @macro seeCustomWidget
        def contents
          VBox(
            table,
            Left(device_buttons)
          )
        end

        # @see Base
        def state_info
          { table.widget_id => table.ui_open_items }
        end

        private

        # @return [String]
        attr_reader :hostname

        # @return [CWM::TreePager]
        attr_reader :pager

        # The table contains all storage devices, including Software RAIDs and LVM Vgs
        #
        # @return [ConfigurableBlkDevicesTable]
        def table
          return @table unless @table.nil?

          @table = ConfigurableBlkDevicesTable.new(devices, @pager, device_buttons)
          @table.remove_columns(Columns::RegionStart, Columns::RegionEnd)
          @table
        end

        # Widget with the dynamic set of buttons for the selected row
        #
        # @return [DeviceButtonsSet]
        def device_buttons
          @device_buttons ||= DeviceButtonsSet.new(pager)
        end

        # Returns all storage devices
        #
        # @note Software RAIDs and LVM Vgs are included.
        #
        # @return [Array<Y2Storage::Device>]
        def devices
          disk_devices + software_raids + lvm_vgs + nfs_devices + bcaches + multidevice_filesystems +
            tmp_filesystems
        end

        # @return [Array<DeviceTableEntry>]
        def disk_devices
          # Since XEN virtual partitions are listed at the end of the "Hard
          # Disks" section, let's do the same in the general storage table
          all = device_graph.disk_devices + device_graph.stray_blk_devices
          all.map do |disk|
            DeviceTableEntry.new_with_children(disk)
          end
        end

        # Returns all LVM volume groups and their logical volumes, including thin pools
        # and thin volumes
        #
        # @see Y2Storage::LvmVg#all_lvm_lvs
        #
        # @return [Array<DeviceTableEntry>]
        def lvm_vgs
          device_graph.lvm_vgs.map do |vg|
            DeviceTableEntry.new_with_children(vg)
          end
        end

        # @return [Array<DeviceTableEntry>]
        def software_raids
          device_graph.software_raids.map do |raid|
            DeviceTableEntry.new_with_children(raid)
          end
        end

        # @return [Array<DeviceTableEntry>]
        def nfs_devices
          device_graph.nfs_mounts.map do |nfs|
            DeviceTableEntry.new(nfs)
          end
        end

        # @return [Array<DeviceTableEntry>]
        def bcaches
          device_graph.bcaches.map do |bcache|
            DeviceTableEntry.new_with_children(bcache)
          end
        end

        # @return [Array<DeviceTableEntry>]
        def multidevice_filesystems
          device_graph.blk_filesystems.select(&:multidevice?).map do |fs|
            DeviceTableEntry.new_with_children(fs)
          end
        end

        # @return [Array<DeviceTableEntry>]
        def tmp_filesystems
          device_graph.tmp_filesystems.map { |f| DeviceTableEntry.new(f) }
        end

        def device_graph
          DeviceGraphs.instance.current
        end
      end
    end
  end
end
