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
require "y2partitioner/actions/controllers"

Yast.import "UI"

describe Y2Partitioner::Dialogs::LvmLvInfo do
  before do
    devicegraph_stub("lvm-two-vgs.yml")
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(controller) }

  let(:controller) { Y2Partitioner::Actions::Controllers::LvmLv.new(vg) }

  let(:vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, vg_name) }

  let(:vg_name) { "vg0" }

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

        it "returns false" do
          expect(widget.validate).to be(false)
        end
      end

      context "when the entered lv name is not valid" do
        let(:value) { "$!" }

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          widget.validate
        end

        it "returns false" do
          expect(widget.validate).to be(false)
        end
      end

      context "when the entered lv name is already used by other lv" do
        let(:value) { "lv1" }

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          widget.validate
        end

        it "returns false" do
          expect(widget.validate).to be(false)
        end
      end

      context "when the entered lv name is already used by other thin volume" do
        before do
          create_thin_provisioning(vg)
        end

        let(:value) { "thin1" }

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          widget.validate
        end

        it "returns false" do
          expect(widget.validate).to be(false)
        end
      end

      context "when the entered lv name is valid" do
        let(:value) { "lv3" }

        it "does not show an error popup" do
          expect(Yast::Popup).to_not receive(:Error)
          widget.validate
        end

        it "returns true" do
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

  describe Y2Partitioner::Dialogs::LvmLvInfo::LvTypeSelector do
    def expect_disable(id)
      expect(Yast::UI).to receive(:ChangeWidget).once.with(Id(id), :Enabled, false)
    end

    def expect_not_disable(id)
      expect(Yast::UI).to_not receive(:ChangeWidget).with(Id(id), :Enabled, false)
    end

    before do
      allow(Yast::UI).to receive(:ChangeWidget).and_call_original
    end

    subject(:widget) { described_class.new(controller) }

    include_examples "CWM::AbstractWidget"

    describe "#init" do
      before do
        allow(controller).to receive(:lv_type).and_return(lv_type)
      end

      let(:lv_type) { Y2Storage::LvType::THIN_POOL }

      it "sets the lv type stored in the controller" do
        expect(widget).to receive(:value=).with(lv_type.to_sym)
        widget.init
      end

      context "when there is not any avilable pool volume" do
        it "disables the option for thin volume" do
          expect_disable(:thin)
          subject.init
        end
      end

      context "when there is some avilable pool volume" do
        before do
          create_thin_provisioning(vg)
        end

        it "does not disable the option for thin volume" do
          expect_not_disable(:thin)
          subject.init
        end
      end

      context "when there is no free space for a new logical volume" do
        let(:vg_name) { "vg0" }

        it "disables the option for normal volume" do
          expect_disable(:normal)
          subject.init
        end

        it "disables the option for thin pool" do
          expect_disable(:thin_pool)
          subject.init
        end
      end

      context "when there is free space for a new logical volume" do
        let(:vg_name) { "vg1" }

        it "does not disable the option for normal volume" do
          expect_not_disable(:normal)
          subject.init
        end

        it "does not disable the option for thin pool" do
          expect_not_disable(:thin_pool)
          subject.init
        end
      end
    end

    describe "#store" do
      before do
        allow(widget).to receive(:value).and_return(value)
        allow(widget).to receive(:current_widget).and_return(current_widget)
        allow(current_widget).to receive(:value).and_return(selected_pool)
      end

      let(:value) { :thin_pool }

      let(:current_widget) { Y2Partitioner::Dialogs::LvmLvInfo::ThinPoolSelector.new(controller) }

      let(:selected_pool) { nil }

      it "saves the lv type into the controller" do
        widget.store
        expect(controller.lv_type).to eq(Y2Storage::LvType::THIN_POOL)
      end

      context "when the selected type is normal volume" do
        let(:value) { :normal }

        let(:selected_pool) { instance_double(Y2Storage::LvmLv) }

        it "does not store a thin pool into the controller" do
          widget.store
          expect(controller.thin_pool).to be_nil
        end
      end

      context "when the selected type is a volume" do
        let(:value) { :thin_pool }

        let(:selected_pool) { instance_double(Y2Storage::LvmLv) }

        it "does not store a thin pool into the controller" do
          widget.store
          expect(controller.thin_pool).to be_nil
        end
      end

      context "when selected type is thin volume" do
        let(:value) { :thin }

        let(:selected_pool) { instance_double(Y2Storage::LvmLv) }

        it "stores the selected thin pool into the controller" do
          widget.store
          expect(controller.thin_pool).to eq(selected_pool)
        end
      end
    end
  end

  describe Y2Partitioner::Dialogs::LvmLvInfo::ThinPoolSelector do
    subject(:widget) { described_class.new(controller) }

    include_examples "CWM::AbstractWidget"

    describe "#items" do
      context "when the volume group has no thin pool" do
        it "returns an empty list" do
          expect(subject.items).to be_empty
        end
      end

      context "when the volume group has thin pools" do
        before do
          create_thin_provisioning(vg)
        end

        it "includes all avilable pools" do
          pools = subject.items.map(&:last)
          expect(pools).to contain_exactly("pool1", "pool2")
        end
      end
    end
  end
end
