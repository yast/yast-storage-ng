#!/usr/bin/env rspec
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

require_relative "../test_helper"

require "yast"
require "cwm/rspec"
require "y2storage"
require "y2partitioner/dialogs/md"
require "y2partitioner/actions/controllers"

Yast.import "UI"

describe Y2Partitioner::Dialogs::Md do
  before { devicegraph_stub("lvm-two-vgs.yml") }

  let(:controller) do
    Y2Partitioner::Actions::Controllers::Md.new
  end

  subject { described_class.new(controller) }

  include_examples "CWM::Dialog"

  describe "#contents" do
    it "contains a widget for entering the MD RAID name" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Dialogs::Md::NameEntry)
      end
      expect(widget).to_not be_nil
    end

    it "contains a widget for selecting the MD RAID level" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Dialogs::Md::LevelChoice)
      end
      expect(widget).to_not be_nil
    end

    it "contains a widget for selecting the MD RAID devices" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Widgets::MdDevicesSelector)
      end
      expect(widget).to_not be_nil
    end
  end

  describe Y2Partitioner::Dialogs::Md::LevelChoice do
    let(:devices_selection) { double("DevicesSelection", refresh_sizes: nil) }

    subject(:widget) { described_class.new(controller, devices_selection) }

    before { allow(Yast::UI).to receive(:QueryWidget).and_return :raid0 }

    include_examples "CWM::CustomWidget"

    describe "#handle" do
      it "sets the level of the RAID and updates the sizes in the UI afterwards" do
        allow(Yast::UI).to receive(:QueryWidget).and_return :raid10
        expect(controller).to receive(:md_level=).with(Y2Storage::MdLevel::RAID10).ordered
        expect(devices_selection).to receive(:refresh_sizes).ordered

        widget.handle
      end
    end
  end

  describe Y2Partitioner::Dialogs::Md::NameEntry do
    include_examples "CWM::AbstractWidget"
  end
end
