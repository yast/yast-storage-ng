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
require "y2partitioner/widgets/device_button"
require "y2partitioner/actions/add_partition"

module Y2Partitioner
  module Widgets
    # Button for adding a partition
    class PartitionAddButton < DeviceButton
      # Constructor
      # @param pager [CWM::TreePager]
      # @param table [Y2Partitioner::Widgets::ConfigurableBlkDevicesTable]
      # @param device [Y2Storage::Device]
      # @param short [Boolean] whether to display a short "Add" label
      def initialize(pager: nil, table: nil, device: nil, short: false)
        super(pager: pager, table: table, device: device)
        @short_label = short
        textdomain "storage"
      end

      # @macro seeAbstractWidget
      #
      # The label depends on the page where the button is used, which is
      # indicated using the :short flag in the constructor
      def label
        # TRANSLATORS: label for button to add a partition
        @short_label ? _("Add...") : _("Add Partition...")
      end

    private

      # When the selected device is a partition, its partitionable (disk, dasd,
      # multipath or BIOS RAID) is considered as the selected device
      #
      # @see DeviceButton#device
      #
      # @return [Y2Storage::Device, nil]
      def device
        dev = super
        return dev if dev.nil?

        dev.is?(:partition) ? dev.partitionable : dev
      end

      # Returns the proper Actions class for adding a partition
      #
      # @see DeviceButton#actions
      # @see Actions::AddPartition
      def actions_class
        Actions::AddPartition
      end
    end
  end
end
