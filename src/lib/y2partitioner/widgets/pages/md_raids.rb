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

require "cwm/tree_pager"
require "y2partitioner/icons"
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/md_raids_table"
require "y2partitioner/widgets/md_add_button"
require "y2partitioner/widgets/blk_device_edit_button"
require "y2partitioner/widgets/device_resize_button"
require "y2partitioner/widgets/device_delete_button"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for Software RAIDs. It contains a {MdRaidsTable}.
      class MdRaids < CWM::Page
        include Yast::I18n
        extend Yast::I18n

        # Constructor
        #
        # @param pager [CWM::TreePager]
        def initialize(pager)
          textdomain "storage"

          @pager = pager
        end

        # Label for all the instances
        #
        # @see #label
        #
        # @return [String]
        def self.label
          N_("RAID")
        end

        # @macro seeAbstractWidget
        def label
          _(self.class.label)
        end

        # @macro seeCustomWidget
        def contents
          return @contents if @contents

          icon = Icons.small_icon(Icons::RAID)
          @contents = VBox(
            Left(
              HBox(
                Image(icon, ""),
                # TRANSLATORS: Heading
                Heading(_("RAID"))
              )
            ),
            table,
            Left(
              HBox(
                MdAddButton.new,
                BlkDeviceEditButton.new(table: table),
                DeviceResizeButton.new(pager: @pager, table: table),
                DeviceDeleteButton.new(pager: @pager, table: table)
              )
            )
          )
        end

      private

        # Table with all Software RAIDs
        #
        # @return [MdRaidsTable]
        def table
          @table ||= MdRaidsTable.new(devices, @pager)
        end

        # Returns all Software RAIDs
        #
        # @return [Array<Y2Storage::Md>]
        def devices
          devicegraph = DeviceGraphs.instance.current
          devicegraph.software_raids
        end
      end
    end
  end
end
