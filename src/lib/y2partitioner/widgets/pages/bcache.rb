# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "y2partitioner/widgets/blk_device_edit_button"
require "y2partitioner/widgets/bcache_edit_button"
require "y2partitioner/widgets/device_delete_button"
require "y2partitioner/widgets/partition_table_add_button"
require "y2partitioner/widgets/partitions_tab"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for a bcache device
      class Bcache < CWM::Page
        # @return [Y2Storage::Bcache] Device this page is about
        attr_reader :bcache
        alias_method :device, :bcache

        # Constructor
        #
        # @param bcache [Y2Storage::Bcache]
        # @param pager [CWM::TreePager]
        def initialize(bcache, pager)
          textdomain "storage"

          @bcache = bcache
          @pager = pager
          self.widget_id = "bcache:" + bcache.name
        end

        # @macro seeAbstractWidget
        def label
          device.basename
        end

        # @macro seeCustomWidget
        def contents
          icon = Icons.small_icon(Icons::BCACHE)
          VBox(
            Left(
              HBox(
                Image(icon, ""),
                # TRANSLATORS: Heading. String followed a device name like /dev/bcache0
                Heading(format(_("Bcache: %s"), device.name))
              )
            ),
            Tabs.new(
              BcacheTab.new(device),
              PartitionsTab.new(device, @pager)
            )
          )
        end
      end

      # A Tab for a Bcache description and its buttons
      class BcacheTab < CWM::Tab
        # Constructor
        #
        # @param bcache [Y2Storage::Bcache]
        def initialize(bcache)
          textdomain "storage"

          @bcache = bcache
        end

        # @macro seeAbstractWidget
        def label
          _("&Overview")
        end

        # @macro seeCustomWidget
        def contents
          # Page wants a WidgetTerm, not an AbstractWidget
          @contents ||=
            VBox(
              BcacheDeviceDescription.new(@bcache),
              Left(HBox(*buttons))
            )
        end

      private

        # @return [Array<Widgets::DeviceButton>]
        def buttons
          [
            BlkDeviceEditButton.new(device: @bcache),
            BcacheEditButton.new(device: @bcache),
            DeviceDeleteButton.new(device: @bcache),
            PartitionTableAddButton.new(device: @bcache)
          ]
        end
      end
    end
  end
end
