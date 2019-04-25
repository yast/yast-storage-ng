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
          devices_info
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
          # TRANSLATORS: BTRFS page title, where %{fs_type} is replaced by the filesystem
          # type (i.e., Btrfs) and %{info} is replaced by the device basename (e.g., sda1).
          format(
            _("%{fs_type}: %{info}"),
            fs_type: filesystem.type.to_human,
            info:    devices_info
          )
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
            UsedDevicesTab.new(devices, pager)
          ]

          Tabs.new(*tabs)
        end

        # Short information about the devices used by the filesystem
        #
        # When the filesystem is a non-multidevice, this method simply returns the base
        # name of the blk device (e.g., "sda1"). And for multidevice ones, it only returns
        # the base name of the first blk device plus a "+" symbol to indicate that the
        # filesystem is multidevice (e.g., "sda1+").
        #
        # @return [String]
        def devices_info
          info = devices.first.basename
          info << "+" if filesystem.multidevice?

          info
        end

        # Devices used by the filesystem
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def devices
          filesystem.blk_devices
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
            BtrfsEditButton.new(device: @filesystem)
          ]
        end
      end
    end
  end
end
