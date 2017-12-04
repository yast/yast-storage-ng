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
require "y2partitioner/widgets/lvm_lv_description"
require "y2partitioner/widgets/lvm_edit_button"
require "y2partitioner/widgets/device_resize_button"
require "y2partitioner/widgets/device_delete_button"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for a LVM Logical Volume
      class LvmLv < CWM::Page
        # @param lvm_lv [Y2Storage::LvmLv]
        def initialize(lvm_lv)
          textdomain "storage"

          @lvm_lv = lvm_lv
          self.widget_id = "lvm_lv:" + lvm_lv.name
        end

        # @return [Y2Storage::LvmLv] logical volume the page is about
        def device
          @lvm_lv
        end

        # @macro seeAbstractWidget
        def label
          @lvm_lv.lv_name
        end

        # @macro seeCustomWidget
        def contents
          return @contents if @contents

          icon = Icons.small_icon(Icons::LVM_LV)
          @contents = VBox(
            Left(
              HBox(
                Image(icon, ""),
                # TRANSLATORS: Heading. String followed by name of partition
                Heading(format(_("Logical Volume: %s"), @lvm_lv.name))
              )
            ),
            LvmLvDescription.new(@lvm_lv),
            Left(
              HBox(
                LvmEditButton.new(device: @lvm_lv),
                DeviceResizeButton.new(device: @lvm_lv),
                DeviceDeleteButton.new(device: @lvm_lv)
              )
            )
          )
        end
      end
    end
  end
end
