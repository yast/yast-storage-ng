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
require "y2partitioner/sequences/controllers"

describe Y2Partitioner::Dialogs::LvmLvSize do
  using Y2Storage::Refinements::SizeCasts

  before do
    devicegraph_stub("lvm-two-vgs.yml")
  end

  subject { described_class.new(controller) }

  let(:controller) { Y2Partitioner::Sequences::Controllers::LvmLv.new(vg) }

  let(:vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  include_examples "CWM::Dialog"

  describe Y2Partitioner::Dialogs::LvmLvSize::SizeWidget do
    subject(:widget) { described_class.new(controller) }

    include_examples "CWM::CustomWidget"

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

    before do
      allow(widget).to receive(:value).and_return(value)
    end

    let(:value) { nil }

    include_examples "CWM::AbstractWidget"

    describe "#validate" do
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
  end

  describe Y2Partitioner::Dialogs::LvmLvSize::StripesWidget do
    subject(:widget) { described_class.new(controller) }

    include_examples "CWM::CustomWidget"

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
