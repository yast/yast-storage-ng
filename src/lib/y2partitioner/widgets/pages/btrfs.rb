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

require "cwm/widget"
require "y2partitioner/icons"
require "y2partitioner/widgets/used_devices_tab"
require "y2partitioner/widgets/filesystem_description"
require "y2partitioner/widgets/btrfs_edit_button"
require "y2partitioner/widgets/used_devices_edit_button"
require "y2partitioner/widgets/device_delete_button"
require "y2partitioner/widgets/tabs"

module Y2Partitioner
  module Widgets
    module Pages
      # Page for a BTRFS filesystem
      #
      # This page contains a {FilesystemTab} and a {UsedDevicesTab}.
      class Btrfs < CWM::Page
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
          VBox(
            Left(
              HBox(
                Image(icon, ""),
                Heading(title)
              )
            ),
            tabs
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
            FilesystemTab.new(filesystem, initial: true),
            BtrfsDevicesTab.new(filesystem, pager)
          ]

          Tabs.new(*tabs)
        end
      end

      # A Tab for filesystem description
      class FilesystemTab < CWM::Tab
        # Constructor
        #
        # @param filesystem [Y2Storage::Filesystems::Btrfs]
        # @param initial [Boolean]
        def initialize(filesystem, initial: false)
          textdomain "storage"

          @filesystem = filesystem
          @initial = initial
        end

        # @macro seeAbstractWidget
        def label
          _("&Overview")
        end

        # @macro seeCustomWidget
        def contents
          @contents ||=
            VBox(
              FilesystemDescription.new(@filesystem),
              Left(HBox(*buttons))
            )
        end

      private

        # @return [Array<Widgets::DeviceButton>]
        def buttons
          [
            BtrfsEditButton.new(device: @filesystem),
            DeviceDeleteButton.new(device: @filesystem)
          ]
        end
      end

      # A Tab for the devices used by a Btrfs
      class BtrfsDevicesTab < UsedDevicesTab
        # Constructor
        #
        # @param filesystem [Y2Storage::Filesystems::Btrfs]
        # @param pager [CWM::TreePager]
        def initialize(filesystem, pager)
          @filesystem = filesystem

          super(devices, pager)
        end

        # @macro seeCustomWidget
        def contents
          @contents ||= VBox(
            table,
            Right(UsedDevicesEditButton.new(device: filesystem))
          )
        end

      private

        # @return [Y2Storage::Filesystems::Btrfs]
        attr_reader :filesystem

        # Devices used by the filesystem
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def devices
          filesystem.plain_blk_devices
        end
      end
    end
  end
end
