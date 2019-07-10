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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2storage"
require "y2partitioner/dialogs"
require "y2partitioner/actions/controllers"

describe Y2Partitioner::Dialogs::LvmLvSize do
  using Y2Storage::Refinements::SizeCasts

  before do
    devicegraph_stub("lvm-two-vgs.yml")
  end

  subject { described_class.new(controller) }

  let(:controller) { Y2Partitioner::Actions::Controllers::LvmLv.new(vg) }

  let(:vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  include_examples "CWM::Dialog"

  describe Y2Partitioner::Dialogs::LvmLvSize::SizeWidget do
    subject(:widget) { described_class.new(controller) }

    include_examples "CWM::CustomWidget"

    describe "#init" do
      before do
        controller.size_choice = :custom
      end

      it "sets the controller value" do
        expect(subject).to receive(:value=).with(:custom)
        subject.init
      end
    end

    describe "#store" do
      before do
        allow(widget).to receive(:value).and_return(value)

        allow(Y2Partitioner::Dialogs::LvmLvSize::MaxSizeDummy)
          .to receive(:new).and_return(max_size_widget)

        allow(Y2Partitioner::Dialogs::LvmLvSize::CustomSizeInput)
          .to receive(:new).and_return(custom_size_widget)
      end

      let(:max_size_widget) { double("MaxSizeDummy", size: max_size) }

      let(:custom_size_widget) { double("CustomSizeInput", size: custom_size) }

      let(:max_size) { nil }

      let(:custom_size) { nil }

      let(:value) { :custom_size }

      it "sets #size_choice in the controller" do
        expect(controller.size_choice).to be_nil
        widget.store
        expect(controller.size_choice).to eq(value)
      end

      context "when max size is selected" do
        let(:value) { :max_size }

        let(:max_size) { 10.GiB }

        it "sets #size in the controller to max possible size" do
          widget.store
          expect(controller.size).to eq(max_size)
        end
      end

      context "when custom size is selected" do
        let(:value) { :custom_size }

        let(:custom_size) { 1.GiB }

        it "sets #size in the controller to the given value" do
          widget.store
          expect(controller.size).to eq(custom_size)
        end
      end
    end
  end

  describe Y2Partitioner::Dialogs::LvmLvSize::MaxSizeDummy do
    subject(:widget) { described_class.new(1.GiB) }

    include_examples "CWM::AbstractWidget"
  end

  describe Y2Partitioner::Dialogs::LvmLvSize::CustomSizeInput do
    subject(:widget) { described_class.new(5.GiB, 1.GiB, 10.GiB) }

    include_examples "CWM::AbstractWidget"

    describe "#validate" do
      before do
        allow(widget).to receive(:value).and_return(value)
      end

      let(:value) { nil }

      context "when given value in not a valid size" do
        let(:value) { nil }

        it "returns false" do
          expect(widget.validate).to eq(false)
        end

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          widget.validate
        end
      end

      context "when given value is less than min size" do
        let(:value) { 1.KiB }

        it "returns false" do
          expect(widget.validate).to eq(false)
        end

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          widget.validate
        end
      end

      context "when given value in bigger than max size" do
        let(:value) { 100.GiB }

        it "returns false" do
          expect(widget.validate).to eq(false)
        end

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          widget.validate
        end
      end

      context "when given value in between min and max sizes" do
        let(:value) { 6.GiB }

        it "returns true" do
          expect(widget.validate).to eq(true)
        end

        it "does not show an error popup" do
          expect(Yast::Popup).to_not receive(:Error)
          widget.validate
        end
      end
    end

    describe "#value" do
      before do
        allow(Yast::UI).to receive(:QueryWidget).with(Id(widget.widget_id), :Value)
          .and_return entered
      end

      context "when a valid size is entered" do
        let(:entered) { "10 GiB" }

        it "returns the corresponding DiskSize object" do
          expect(widget.value).to eq 10.GiB
        end
      end

      context "when no units are specified" do
        let(:entered) { "10" }

        it "returns a DiskSize object" do
          expect(widget.value).to be_a Y2Storage::DiskSize
        end

        it "considers the units to be bytes" do
          expect(widget.value.to_i).to eq 10
        end
      end

      context "when International System units are used" do
        let(:entered) { "10gb" }

        it "considers them as base 2 units" do
          expect(widget.value).to eq 10.GiB
        end
      end

      context "when the units are only partially specified" do
        let(:entered) { "10g" }

        it "considers them as base 2 units" do
          expect(widget.value).to eq 10.GiB
        end
      end

      context "when nothing is entered" do
        let(:entered) { "" }

        it "returns nil" do
          expect(widget.value).to be_nil
        end
      end

      context "when an invalid string is entered" do
        let(:entered) { "a big chunk" }

        it "returns nil" do
          expect(widget.value).to be_nil
        end
      end
    end
  end

  describe Y2Partitioner::Dialogs::LvmLvSize::StripesWidget do
    subject(:widget) { described_class.new(controller) }

    include_examples "CWM::CustomWidget"

    describe "#init" do
      before do
        allow(controller).to receive(:lv_type).and_return(lv_type)
      end

      let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

      let(:stripes_number_widget) do
        widgets.detect { |w| w.is_a?(Y2Partitioner::Dialogs::LvmLvSize::StripesNumberSelector) }
      end

      let(:stripes_size_widget) do
        widgets.detect { |w| w.is_a?(Y2Partitioner::Dialogs::LvmLvSize::StripesSizeSelector) }
      end

      context "when a normal volume is being created" do
        let(:lv_type) { Y2Storage::LvType::NORMAL }

        it "does not disable the widget for stripes number" do
          expect(stripes_number_widget).to_not receive(:disable)
          subject.init
        end

        it "does not disable the widget for stripes size" do
          expect(stripes_size_widget).to_not receive(:disable)
          subject.init
        end
      end

      context "when a thin pool is being created" do
        let(:lv_type) { Y2Storage::LvType::THIN_POOL }

        it "does not disable the widget for stripes number" do
          expect(stripes_number_widget).to_not receive(:disable)
          subject.init
        end

        it "does not disable the widget for stripes size" do
          expect(stripes_size_widget).to_not receive(:disable)
          subject.init
        end
      end

      context "when a thin volume is being created" do
        let(:lv_type) { Y2Storage::LvType::THIN }

        it "disables the widget for stripes number" do
          expect(stripes_number_widget).to receive(:disable)
          subject.init
        end

        it "disables the widget for stripes size" do
          expect(stripes_size_widget).to receive(:disable)
          subject.init
        end
      end
    end

    describe "#store" do
      before do
        allow(Y2Partitioner::Dialogs::LvmLvSize::StripesNumberSelector)
          .to receive(:new).and_return(stripes_number_widget)

        allow(Y2Partitioner::Dialogs::LvmLvSize::StripesSizeSelector)
          .to receive(:new).and_return(stripes_size_widget)
      end

      let(:stripes_number_widget) do
        instance_double(Y2Partitioner::Dialogs::LvmLvSize::StripesNumberSelector, value: stripes_number)
      end

      let(:stripes_size_widget) do
        instance_double(Y2Partitioner::Dialogs::LvmLvSize::StripesSizeSelector, value: stripes_size)
      end

      let(:stripes_number) { 3 }

      let(:stripes_size) { 4.KiB }

      it "sets #stripes_number in the controller" do
        expect(controller.stripes_number).to be_nil
        widget.store
        expect(controller.stripes_number).to eq(stripes_number)
      end

      it "sets #stripes_size in the controller" do
        expect(controller.stripes_size).to be_nil
        widget.store
        expect(controller.stripes_size).to eq(stripes_size)
      end
    end
  end

  describe Y2Partitioner::Dialogs::LvmLvSize::StripesNumberSelector do
    subject(:widget) { described_class.new(controller) }

    include_examples "CWM::AbstractWidget"
  end

  describe Y2Partitioner::Dialogs::LvmLvSize::StripesSizeSelector do
    subject(:widget) { described_class.new(controller) }

    include_examples "CWM::AbstractWidget"
  end
end
