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

require "cwm/pager"
require "y2partitioner/icons"
require "y2partitioner/widgets/blk_device_edit_button"
require "y2partitioner/widgets/partition_move_button"
require "y2partitioner/widgets/device_resize_button"
require "y2partitioner/widgets/device_delete_button"
require "y2partitioner/widgets/partition_description"
require "y2partitioner/dialogs"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for a partition
      class Partition < CWM::Page
        # Constructor
        #
        # @param [Y2Storage::Partition] partition
        def initialize(partition)
          textdomain "storage"

          @partition = partition
          self.widget_id = "partition:" + partition.name
        end

        # @return [Y2Storage::Partition] partition the page is about
        def device
          @partition
        end

        # @macro seeAbstractWidget
        def label
          @partition.basename
        end

        # @macro seeCustomWidget
        def contents
          # FIXME: this is called dozens of times per single click!!
          return @contents if @contents

          @contents = VBox(
            Left(
              HBox(
                Image(Icons::HD_PART, ""),
                # TRANSLATORS: Heading. String followed by name of partition
                Heading(format(_("Partition: %s"), @partition.name))
              )
            ),
            PartitionDescription.new(@partition),
            Left(
              HBox(
                BlkDeviceEditButton.new(device: @partition),
                PartitionMoveButton.new(device: @partition),
                DeviceResizeButton.new(device: @partition),
                DeviceDeleteButton.new(device: @partition)
              )
            )
          )
        end
      end
    end
  end
end
