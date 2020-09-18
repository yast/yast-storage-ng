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

require "y2partitioner/icons"
require "y2partitioner/widgets/pages/base"
require "y2partitioner/widgets/pages/bcaches"
require "y2partitioner/widgets/bcache_edit_button"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for a bcache device
      class Bcache < Base
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
          Top(
            VBox(
              Left(
                HBox(
                  Image(Icons::BCACHE, ""),
                  # TRANSLATORS: Heading. String followed by a device name like /dev/bcache0
                  Heading(format(_("Bcache: %s"), device.name))
                )
              ),
              Left(
                Tabs.new(
                  BcacheTab.new(device, @pager),
                  BcacheDevicesTab.new(device, @pager)
                )
              )
            )
          )
        end

        private

        # @return [String]
        def section
          Bcaches.label
        end
      end

      # A Tab for a Bcache description and its buttons
      class BcacheTab < OverviewTab
        private

        def devices
          [
            BlkDevicesTable::DeviceTree.new(device, children: device.partitions)
          ]
        end
      end

      # A Tab for the backing device and cset of a Bcache
      class BcacheDevicesTab < UsedDevicesTab
        # Constructor
        #
        # @param md [Y2Storage::Md]
        # @param pager [CWM::TreePager]
        # @param initial [Boolean] if it is the initial tab
        def initialize(bcache, pager, initial: false)
          textdomain "storage"

          devices = ([bcache.backing_device] + bcache.bcache_cset.blk_devices).compact
          super(devices, pager)
          @bcache = bcache
          @initial = initial
        end

        # @macro seeCustomWidget
        def contents
          @contents ||= VBox(
            table,
            Right(BcacheEditButton.new(device: @bcache))
          )
        end
      end
    end
  end
end
