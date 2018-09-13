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
require "cwm/tree_pager"
require "y2partitioner/icons"
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/widgets/rescan_devices_button"
require "y2partitioner/widgets/import_mount_points_button"
require "y2partitioner/widgets/configure"

Yast.import "Mode"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for all storage devices in the system
      class System < CWM::Page
        include Yast::I18n

        # Constructor
        #
        # @param [String] hostname of the system, to be displayed
        # @param pager [CWM::TreePager]
        def initialize(hostname, pager)
          textdomain "storage"

          @pager = pager
          @hostname = hostname
        end

        # @macro seeAbstractWidget
        def label
          hostname
        end

        # @macro seeCustomWidget
        def contents
          invalidate_cached_content
          return @contents if @contents

          @contents = VBox(
            Left(header),
            table,
            HBox(*buttons)
          )
        end

      private

        # @return [String]
        attr_reader :hostname

        # @return [CWM::TreePager]
        attr_reader :pager

        # Invalidates cached content if needed according to
        # {OverviewTreePager#invalidated_views}
        def invalidate_cached_content
          return unless pager.invalidated_pages.delete(:system)

          @contents = nil
          @table = nil
        end

        # Page header
        #
        # @return [Yast::UI::Term]
        def header
          icon = Icons.small_icon(Icons::ALL)

          HBox(
            Image(icon, ""),
            # TRANSLATORS: Heading. String followed by the hostname
            Heading(format(_("Available Storage on %s"), hostname))
          )
        end

        # The table contains all storage devices, including Software RAIDs and LVM Vgs
        #
        # @return [ConfigurableBlkDevicesTable]
        def table
          return @table unless @table.nil?
          @table = ConfigurableBlkDevicesTable.new(devices, @pager)
          @table.remove_columns(:start, :end)
          @table
        end

        # Page buttons
        #
        # @return [Array<Yast::UI::Term>]
        def buttons
          buttons = [rescan_devices_button]
          buttons << import_mount_points_button if Yast::Mode.installation
          buttons << HStretch()
          buttons << Configure.new
          buttons
        end

        # Button for rescanning devices
        #
        # @return [RescanDevicesButton]
        def rescan_devices_button
          RescanDevicesButton.new
        end

        # Button for importing mount points
        #
        # @return [ImportMountPointsButton]
        def import_mount_points_button
          ImportMountPointsButton.new
        end

        # Returns all storage devices
        #
        # @note Software RAIDs and LVM Vgs are included.
        #
        # @return [Array<Y2Storage::Device>]
        def devices
          disk_devices + software_raids + lvm_vgs + nfs_devices + bcache_devices
        end

        # @return [Array<Y2Storage::Device>]
        def disk_devices
          # Since XEN virtual partitions are listed at the end of the "Hard
          # Disks" section, let's do the same in the general storage table
          all = device_graph.disk_devices + device_graph.stray_blk_devices
          all.each_with_object([]) do |disk, devices|
            devices << disk
            devices.concat(disk.partitions) if disk.respond_to?(:partitions)
          end
        end

        # Returns all LVM volume groups and their logical volumes, including thin pools
        # and thin volumes
        #
        # @see Y2Storage::LvmVg#all_lvm_lvs
        #
        # @return [Array<Y2Storage::LvmVg, Y2Storage::LvmLv>]
        def lvm_vgs
          device_graph.lvm_vgs.reduce([]) do |devices, vg|
            devices << vg
            devices.concat(vg.all_lvm_lvs)
          end
        end

        # @return [Array<Y2Storage::Device>]
        def software_raids
          device_graph.software_raids
        end

        # @return [Array<Y2Storage::Device>]
        def nfs_devices
          device_graph.nfs_mounts
        end

        # @return [Array<Y2Storage::Device>]
        def bcache_devices
          all = device_graph.bcaches
          all.each_with_object([]) do |bcache, devices|
            devices << bcache
            devices.concat(bcache.partitions) if bcache.respond_to?(:partitions)
          end
        end

        def device_graph
          DeviceGraphs.instance.current
        end
      end
    end
  end
end
