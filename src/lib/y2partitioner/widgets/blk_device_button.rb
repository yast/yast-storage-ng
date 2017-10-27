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
require "cwm"

module Y2Partitioner
  module Widgets
    # Base button class for modifying a block device (edit, resize, delete, etc)
    class BlkDeviceButton < CWM::PushButton
      # Constructor
      # @param pager [CWM::TreePager]
      # @param table [Y2Partitioner::Widgets::ConfigurableBlkDevicesTable]
      # @param device [Y2Storage::BlkDevice]
      def initialize(pager: nil, table: nil, device: nil)
        textdomain "storage"

        unless device || table
          raise ArgumentError, "Please provide either a block device or a table with devices"
        end

        @pager = pager
        @table = table
        @device = device
      end

      # @macro seeAbstractWidget
      def handle
        return nil unless validate_presence
        actions
      end

    protected

      # @return [CWM::TreePager]
      attr_reader :pager

      # @return [Y2Partitioner::Widgets::ConfigurableBlkDevicesTable]
      attr_reader :table

      # Device on which to act
      def device
        @device || table.selected_device
      end

      # Actions to perform when the button is clicked
      # @return [Symbol, nil] result
      abstract_method :actions

      # Checks whether there is a device on which to act
      #
      # @note An error popup is shown when there is no device.
      #
      # @return [Boolean]
      def validate_presence
        return true unless device.nil?

        Yast::Popup.Error(_("No device selected"))
        false
      end
    end
  end
end
