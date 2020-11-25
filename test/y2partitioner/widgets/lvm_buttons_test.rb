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

require "y2partitioner/widgets/lvm_buttons"

describe Y2Partitioner::Widgets::LvmVgAddButton do
  let(:action) { Y2Partitioner::Actions::AddLvmVg }

  let(:scenario) { "one-empty-disk" }

  include_examples "add button"
end

describe Y2Partitioner::Widgets::LvmVgResizeButton do
  let(:action) { Y2Partitioner::Actions::ResizeLvmVg }

  let(:scenario) { "lvm-two-vgs" }

  let(:device) { devicegraph.find_by_name("/dev/vg0") }

  include_examples "button"
end

describe Y2Partitioner::Widgets::LvmVgDeleteButton do
  let(:action) { Y2Partitioner::Actions::DeleteLvmVg }

  let(:scenario) { "lvm-two-vgs" }

  let(:device) { devicegraph.find_by_name("/dev/vg0") }

  include_examples "button"
end

describe Y2Partitioner::Widgets::LvmLvAddButton do
  let(:scenario) { "lvm-two-vgs" }

  let(:action) { Y2Partitioner::Actions::AddLvmLv }

  include_context "device button context"

  describe "#handle" do
    include_examples "handle without device"

    context "when a volume group is given" do
      let(:device) { devicegraph.find_by_name("/dev/vg0") }

      it "starts the action to add a logical volume over the volume group" do
        expect(action).to receive(:new).with(device).and_return(double("action", run: nil))

        subject.handle
      end

      include_examples "handle result"
    end

    context "when a logical volume is given" do
      let(:device) { devicegraph.find_by_name("/dev/vg0/lv1") }

      it "starts the action to add a logical volume over its volume group" do
        expect(action).to receive(:new).with(device.lvm_vg).and_return(double("action", run: nil))

        subject.handle
      end

      include_examples "handle result"
    end
  end
end

describe Y2Partitioner::Widgets::LvmLvDeleteButton do
  let(:action) { Y2Partitioner::Actions::DeleteLvmLv }

  let(:scenario) { "lvm-two-vgs" }

  let(:device) { devicegraph.find_by_name("/dev/vg0/lv1") }

  include_examples "button"
end
