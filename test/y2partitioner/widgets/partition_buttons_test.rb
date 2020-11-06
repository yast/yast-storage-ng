# Copyright (c) [2020] SUSE LLC
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
# find current contact information at www.suse.com

require_relative "../test_helper"
require_relative "button_context"
require_relative "button_examples"

require "y2partitioner/widgets/partition_buttons"

describe Y2Partitioner::Widgets::PartitionAddButton do
  let(:scenario) { "mixed_disks" }

  let(:action) { Y2Partitioner::Actions::AddPartition }

  include_context "device button context"

  describe "#handle" do
    include_examples "handle without device"

    context "when a disk device is given" do
      let(:device) { devicegraph.find_by_name("/dev/sda") }

      it "starts the action to add a partition over the disk device" do
        expect(action).to receive(:new).with(device).and_return(double("action", run: nil))

        subject.handle
      end

      include_examples "handle result"
    end

    context "when a partition is given" do
      let(:device) { devicegraph.find_by_name("/dev/sda1") }

      it "starts the action to add a partition over its disk device" do
        expect(action).to receive(:new).with(device.partitionable).and_return(double("action", run: nil))

        subject.handle
      end

      include_examples "handle result"
    end
  end
end

describe Y2Partitioner::Widgets::PartitionDeleteButton do
  let(:scenario) { "mixed_disks" }

  let(:action) { Y2Partitioner::Actions::DeletePartition }

  let(:device) { devicegraph.find_by_name("/dev/sda1") }

  include_examples "button"
end
