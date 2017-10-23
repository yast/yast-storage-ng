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

require "cwm/rspec"
require "y2storage"
require "y2partitioner/dialogs"
require "y2partitioner/sequences/controllers"

describe Y2Partitioner::Dialogs::LvmLvInfo do
  before do
    devicegraph_stub("lvm-two-vgs.yml")
  end

  subject { described_class.new(controller) }

  let(:controller) { Y2Partitioner::Sequences::Controllers::LvmLv.new(vg) }

  let(:vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  include_examples "CWM::Dialog"

  describe Y2Partitioner::Dialogs::LvmLvInfo::NameWidget do
    subject(:widget) { described_class.new(controller) }

    include_examples "CWM::AbstractWidget"

    describe "#init" do
      before do
        controller.lv_name = lv_name
      end

      let(:lv_name) { "lv1" }

      it "sets #value stored in the controller" do
        expect(widget).to receive(:value=).with(lv_name)
        widget.init
      end

      it "gets focus" do
        expect(Yast::UI).to receive(:SetFocus).with(Id(widget.widget_id))
        widget.init
      end
    end

    describe "#validate" do
      before do
        allow(widget).to receive(:value).and_return(value)
      end

      context "when no lv name is entered" do
        let(:value) { nil }

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          widget.validate
        end

        it "return false" do
          expect(widget.validate).to be(false)
        end
      end

      context "when the entered lv name is not valid" do
        let(:value) { "$!" }

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          widget.validate
        end

        it "return false" do
          expect(widget.validate).to be(false)
        end
      end

      context "when the entered lv name is already used" do
        let(:value) { "lv1" }

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          widget.validate
        end

        it "return false" do
          expect(widget.validate).to be(false)
        end
      end

      context "when the entered lv name is valid" do
        let(:value) { "lv3" }

        it "does not show an error popup" do
          expect(Yast::Popup).to_not receive(:Error)
          widget.validate
        end

        it "return true" do
          expect(widget.validate).to be(true)
        end
      end
    end

    describe "#store" do
      before do
        allow(widget).to receive(:value).and_return(value)
      end

      let(:value) { "lv3" }

      it "sets #lv_name in the controller" do
        expect(controller.lv_name).to be_nil
        widget.store
        expect(controller.lv_name).to eq(value)
      end
    end
  end

  describe Y2Partitioner::Dialogs::LvmLvInfo::TypeWidget do
    subject(:widget) { described_class.new(controller) }

    before do
      allow(widget).to receive(:value).and_return(value)
    end

    let(:value) { nil }

    include_examples "CWM::AbstractWidget"

    describe "#store" do
      before do
        allow(widget).to receive(:current_widget).and_return(current_widget)
        allow(current_widget).to receive(:value).and_return(used_pool)
      end

      let(:current_widget) { Y2Partitioner::Dialogs::LvmLvInfo::ThinPoolSelector.new(controller) }

      let(:used_pool) { nil }

      let(:value) { :normal }

      it "sets #type_choice in the controller" do
        expect(controller.type_choice).to be_nil
        widget.store
        expect(controller.type_choice).to eq(value)
      end

      context "when selected type is :thin" do
        let(:value) { :thin }

        let(:used_pool) { "lv_thin_pool" }

        it "sets #thin_pool in the controller" do
          expect(controller.thin_pool).to be_nil
          widget.store
          expect(controller.thin_pool).to eq(used_pool)
        end
      end

      context "when the selected type is not :thin" do
        let(:value) { :normal }

        let(:used_pool) { "lv_thin_pool" }

        before do
          controller.thin_pool = used_pool
        end

        it "sets #thin_pool to nil in the controller" do
          expect(controller.thin_pool).to eq(used_pool)
          widget.store
          expect(controller.thin_pool).to be_nil
        end
      end
    end
  end

  describe Y2Partitioner::Dialogs::LvmLvInfo::ThinPoolSelector do
    subject(:widget) { described_class.new(controller) }

    include_examples "CWM::AbstractWidget"
  end
end
