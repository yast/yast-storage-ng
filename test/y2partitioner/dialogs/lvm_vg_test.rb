#!/usr/bin/env rspec
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

require "cwm/rspec"
require "y2partitioner/dialogs/lvm_vg"
require "y2partitioner/actions/controllers/lvm_vg"

describe Y2Partitioner::Dialogs::LvmVg do
  using Y2Storage::Refinements::SizeCasts

  before do
    devicegraph_stub("complex-lvm-encrypt.yml")
  end

  subject { described_class.new(controller) }

  let(:controller) { Y2Partitioner::Actions::Controllers::LvmVg.new }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  include_examples "CWM::Dialog"

  describe "#contents" do
    it "contains a widget for the vg name" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Dialogs::LvmVg::NameWidget)
      end
      expect(widget).to_not be_nil
    end

    it "contains a widget for the vg extent size" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Dialogs::LvmVg::ExtentSizeWidget)
      end
      expect(widget).to_not be_nil
    end

    it "contains a widget to select devices" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Widgets::LvmVgDevicesSelector)
      end
      expect(widget).to_not be_nil
    end
  end

  describe Y2Partitioner::Dialogs::LvmVg::NameWidget do
    subject { described_class.new(controller) }

    include_examples "CWM::AbstractWidget"

    describe "#init" do
      before do
        controller.vg_name = "vg1"
      end

      it "sets its value with vg name stored in the controller" do
        expect(subject).to receive(:value=).with("vg1")
        subject.init
      end

      it "gets focus" do
        expect(Yast::UI).to receive(:SetFocus).with(Id(subject.widget_id))
        subject.init
      end
    end

    describe "#handle" do
      before do
        allow(subject).to receive(:value).and_return("vg1")
      end

      it "stores in the controller the given vg name" do
        subject.handle
        expect(controller.vg_name).to eq("vg1")
      end

      it "returns nil" do
        expect(subject.handle).to be_nil
      end
    end

    describe "#validate" do
      before do
        controller.vg_name = vg_name
      end

      let(:vg_name) { nil }

      it "gets focus" do
        expect(Yast::UI).to receive(:SetFocus).with(Id(subject.widget_id))
        subject.init
      end

      context "when the vg name is not given" do
        let(:vg_name) { "" }

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          subject.validate
        end

        it "returns false" do
          expect(subject.validate).to eq(false)
        end
      end

      context "when the vg name has invalid characters" do
        let(:vg_name) { "vg%" }

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          subject.validate
        end

        it "returns false" do
          expect(subject.validate).to eq(false)
        end
      end

      context "when a device exists with the given vg name" do
        let(:vg_name) { "sda" }

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          subject.validate
        end

        it "returns false" do
          expect(subject.validate).to eq(false)
        end
      end

      context "when the given vg name is valid" do
        let(:vg_name) { "vg100" }

        it "does not show an error popup" do
          expect(Yast::Popup).to_not receive(:Error)
          subject.validate
        end

        it "returns true" do
          expect(subject.validate).to eq(true)
        end
      end
    end
  end

  describe Y2Partitioner::Dialogs::LvmVg::ExtentSizeWidget do
    subject { described_class.new(controller) }

    include_examples "CWM::AbstractWidget"

    describe "#init" do
      before do
        controller.extent_size = "128 KiB"
      end

      it "sets its value with the extent size stored in the controller" do
        expect(subject).to receive(:value=).with("128 KiB")
        subject.init
      end
    end

    describe "#handle" do
      before do
        allow(subject).to receive(:value).and_return(value)
      end

      let(:value) { "1 MiB" }

      it "stores in the controller the given extent size" do
        expect(controller.extent_size).to_not eq(1.MiB)
        subject.handle
        expect(controller.extent_size).to eq(1.MiB)
      end

      it "returns nil" do
        expect(subject.handle).to be_nil
      end

      context "when no extent size is given" do
        let(:value) { "" }

        before do
          controller.extent_size = "1 MiB"
        end

        it "stores nil in the controller" do
          expect(controller.extent_size).to_not be_nil
          subject.handle
          expect(controller.extent_size).to be_nil
        end
      end

      context "when extent size with not valid format is given" do
        let(:value) { "4 bad units" }

        before do
          controller.extent_size = "1 MiB"
        end

        it "stores nil in the controller" do
          expect(controller.extent_size).to_not be_nil
          subject.handle
          expect(controller.extent_size).to be_nil
        end
      end
    end

    describe "#validate" do
      before do
        allow(controller).to receive(:invalid_extent_size?).and_return(!valid)
      end

      context "when the given extent size is not valid" do
        let(:valid) { false }

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          subject.validate
        end

        it "returns false" do
          expect(subject.validate).to eq(false)
        end
      end

      context "when the given extent size is valid" do
        let(:valid) { true }

        it "does not show an error popup" do
          expect(Yast::Popup).to_not receive(:Error)
          subject.validate
        end

        it "returns true" do
          expect(subject.validate).to eq(true)
        end
      end
    end
  end
end
