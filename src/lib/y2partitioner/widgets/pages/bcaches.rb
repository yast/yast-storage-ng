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

require "cwm/tree_pager"
require "y2partitioner/icons"
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/widgets/bcache_add_button"
require "y2partitioner/device_graphs"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for bcache devices and its partitions. It contains a {ConfigurableBlkDevicesTable}
      class Bcaches < CWM::Page
        include Yast::I18n

        # Constructor
        #
        # @param bcaches [Array<Y2Storage::Bcache>]
        # @param pager [CWM::TreePager]
        def initialize(bcaches, pager)
          textdomain "storage"

          @bcaches = bcaches
          @pager = pager
        end

        # @macro seeAbstractWidget
        def label
          _("Bcache")
        end

        # @macro seeCustomWidget
        def contents
          return @contents if @contents

          device_buttons = DeviceButtonsSet.new(@pager)
          table = ConfigurableBlkDevicesTable.new(devices, @pager, device_buttons)
          icon = Icons.small_icon(Icons::BCACHE)
          @contents = VBox(
            Left(
              HBox(
                Image(icon, ""),
                # TRANSLATORS: Heading
                Heading(_("Bcache"))
              )
            ),
            table,
            Left(device_buttons),
            Right(BcacheAddButton.new)
          )
        end

      private

        # @return [Array<Y2Storage::BlkDevice>]
        attr_reader :bcaches

        # @return [CWM::TreePager]
        attr_reader :pager

        # Returns all bcache devices and their partitions
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def devices
          bcaches.each_with_object([]) do |bcache, devices|
            devices << bcache
            devices.concat(bcache.partitions)
          end
        end
      end
    end
  end
end
