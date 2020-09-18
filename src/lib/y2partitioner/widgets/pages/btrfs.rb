# Copyright (c) [2017-2020] SUSE LLC
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

require "y2partitioner/icons"
require "y2partitioner/widgets/tabs"
require "y2partitioner/widgets/pages/base"
require "y2partitioner/widgets/pages/btrfs_filesystems"
require "y2partitioner/widgets/overview_tab"
require "y2partitioner/widgets/btrfs_filesystems_table"
require "y2partitioner/widgets/used_devices_tab"
require "y2partitioner/widgets/used_devices_edit_button"

module Y2Partitioner
  module Widgets
    module Pages
      # Page for a BTRFS filesystem
      #
      # This page contains a {FilesystemTab} and a {BtrfsUsedDevicesTab}.
      class Btrfs < Base
        # @return [Y2Storage::Filesystems::Btrfs]
        attr_reader :filesystem

        # Needed for searching a device page, see {OverviewTreePager#device_page}
        alias_method :device, :filesystem

        # Constructor
        #
        # @param filesystem [Y2Storage::Filesystems::Btrfs]
        # @param pager [CWM::TreePager]
        def initialize(filesystem, pager)
          textdomain "storage"

          @filesystem = filesystem
          @pager = pager

          self.widget_id = "btrfs:" + filesystem.sid.to_s
        end

        # @macro seeAbstractWidget
        def label
          filesystem.blk_device_basename
        end

        # @macro seeCustomWidget
        def contents
          Top(
            VBox(
              Left(
                HBox(
                  Image(icon, ""),
                  Heading(title)
                )
              ),
              Left(tabs)
            )
          )
        end

        private

        # @return [CWM::TreePager]
        attr_reader :pager

        # Page icon
        #
        # @return [String]
        def icon
          Icons::BTRFS
        end

        # Page title
        #
        # @return [String]
        def title
          # TRANSLATORS: BTRFS page title, where %{basename} is replaced by the device
          # basename (e.g., sda1).
          format(_("Btrfs %{basename}"), basename: filesystem.blk_device_basename)
        end

        # Tabs to show the filesystem data
        #
        # There are two tabs: one for the filesystem info and another one with the devices
        # used by the filesystem.
        #
        # @return [Tabs]
        def tabs
          tabs = [
            FilesystemTab.new(filesystem, pager),
            BtrfsUsedDevicesTab.new(filesystem, pager)
          ]

          Tabs.new(*tabs)
        end

        # @return [String]
        def section
          BtrfsFilesystems.label
        end
      end

      # A tab to represent the Btrfs filesystem
      class FilesystemTab < OverviewTab
        private

        # @return [BtrfsFilesystemsTable]
        def table(buttons_set)
          BtrfsFilesystemsTable.new(devices, @pager, buttons_set)
        end
      end

      # A Tab for the used devices of a Btrfs
      class BtrfsUsedDevicesTab < UsedDevicesTab
        # @see UsedDevicesTab#used_devices
        def used_devices
          device.plain_blk_devices
        end

        # @see UsedDevicesTab#buttons
        def buttons
          Right(UsedDevicesEditButton.new(device: device))
        end
      end
    end
  end
end
