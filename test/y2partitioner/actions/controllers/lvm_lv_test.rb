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

require_relative "../../test_helper"
require "y2partitioner/device_graphs"
require "y2partitioner/actions/controllers/lvm_lv"

describe Y2Partitioner::Actions::Controllers::LvmLv do
  using Y2Storage::Refinements::SizeCasts

  subject(:controller) { described_class.new(vg) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, vg_name) }

  let(:vg_name) { "vg0" }

  before do
    devicegraph_stub("lvm-two-vgs.yml")
  end

  describe "#vg" do
    it "returns a Y2Storage::LvmVg" do
      expect(subject.vg).to be_a(Y2Storage::LvmVg)
    end

    it "returns the currently editing vg" do
      expect(subject.vg).to eq(vg)
    end
  end

  describe "#create_lv" do
    before do
      allow(controller).to receive(:lv_name).and_return(lv_name)
      allow(controller).to receive(:lv_type).and_return(lv_type)
      allow(controller).to receive(:size).and_return(size)
      allow(controller).to receive(:stripes_number).and_return(stripes_number)
      allow(controller).to receive(:stripes_size).and_return(stripes_size)
    end

    let(:lv_name) { "lv3" }

    let(:lv_type) { Y2Storage::LvType::THIN_POOL }

    let(:size) { 3.GiB }

    let(:stripes_number) { 2 }

    let(:stripes_size) { 16.KiB }

    it "creates a new lv in the current vg" do
      expect(controller.vg.lvm_lvs.size).to eq(2)
      controller.create_lv
      expect(controller.vg.lvm_lvs.size).to eq(3)
    end

    it "creates a new lv with indicated values" do
      expect(controller.vg.lvm_lvs.map(&:lv_name)).to_not include(lv_name)

      controller.create_lv
      lv = controller.vg.lvm_lvs.find { |l| l.lv_name == lv_name }

      expect(lv.lv_name).to eq(lv_name)
      expect(lv.lv_type).to eq(lv_type)
      expect(lv.size).to eq(size)
      expect(lv.stripes).to eq(stripes_number)
      expect(lv.stripe_size).to eq(stripes_size)
    end

    it "stores the new created lv" do
      expect(controller.lv).to be_nil

      controller.create_lv

      expect(controller.lv).to_not be_nil
      expect(controller.lv.lv_name).to eq(lv_name)
      expect(controller.lv.lvm_vg).to eq(controller.vg)
    end

    it "select the table row corresponding to the new lv" do
      expect(Y2Partitioner::UIState.instance).to receive(:select_row) do |lv|
        expect(lv).to eq(controller.lv)
      end

      controller.create_lv
    end

    context "when the stored lv type is thin" do
      let(:lv_type) { Y2Storage::LvType::THIN }

      before do
        create_thin_provisioning(vg)

        allow(controller).to receive(:thin_pool).and_return(thin_pool)
      end

      let(:thin_pool) { Y2Storage::BlkDevice.find_by_name(current_graph, "/dev/vg0/pool1") }

      it "creates a thin volume over the indicated thin pool" do
        expect(thin_pool.lvm_lvs.size).to eq(2)
        controller.create_lv
        expect(thin_pool.lvm_lvs.size).to eq(3)
      end
    end
  end

  describe "#delete_lv" do
    context "when a lv has not been created" do
      it "does not modify the editing vg" do
        previous_lvs = controller.vg.lvm_lvs
        controller.delete_lv
        expect(controller.vg.lvm_lvs).to eq(previous_lvs)
      end
    end

    context "when a lv has been created" do
      before do
        allow(controller).to receive(:lv_name).and_return(lv_name)
        allow(controller).to receive(:size).and_return(size)
      end

      let(:lv_name) { "lv3" }

      let(:size) { 1.GiB }

      before do
        controller.create_lv
      end

      it "removes the previously created lv" do
        expect(controller.vg.lvm_lvs.map(&:lv_name)).to include(lv_name)
        controller.delete_lv
        expect(controller.vg.lvm_lvs.map(&:lv_name)).to_not include(lv_name)
      end

      it "sets the current lv to nil" do
        expect(controller.lv).to_not be_nil
        controller.delete_lv
        expect(controller.lv).to be_nil
      end
    end
  end

  describe "#lv_type" do
    context "if no lv type was previously set" do
      before do
        allow(controller).to receive(:vg).and_return(vg)
        allow(vg).to receive(:number_of_free_extents).and_return(free_extents)
      end

      context "and there is no availabe space in the volume group" do
        let(:free_extents) { 0 }

        context "and there is no available pool in the volume group" do
          it "returns normal type" do
            expect(controller.lv_type).to eq(Y2Storage::LvType::NORMAL)
          end
        end

        context "and there are available pools in the volume group" do
          before do
            create_thin_provisioning(vg)
          end

          it "returns thin type" do
            expect(controller.lv_type).to eq(Y2Storage::LvType::THIN)
          end
        end
      end

      context "and there is free availabe space in the volume group" do
        let(:free_extents) { 10 }

        it "returns normal type" do
          expect(controller.lv_type).to eq(Y2Storage::LvType::NORMAL)
        end
      end
    end

    context "if lv type was previously set" do
      before do
        controller.lv_type = Y2Storage::LvType::THIN_POOL
      end

      it "returns that value" do
        expect(controller.lv_type).to eq(Y2Storage::LvType::THIN_POOL)
      end
    end
  end

  describe "#reset_size_and_stripes" do
    before do
      controller.stripes_number = 10
      controller.stripes_size = 16.KiB
    end

    it "sets stripes number to nil" do
      expect(controller.stripes_number).to_not be_nil
      controller.reset_size_and_stripes
      expect(controller.stripes_number).to be_nil
    end

    it "sets stripes size to nil" do
      expect(controller.stripes_size).to_not be_nil
      controller.reset_size_and_stripes
      expect(controller.stripes_size).to be_nil
    end

    context "if the lv type is set to thin" do
      before do
        controller.lv_type = Y2Storage::LvType::THIN
      end

      it "sets size to 2 GiB" do
        controller.reset_size_and_stripes
        expect(controller.size).to eq(2.GiB)
      end

      it "sets size choice to custom size" do
        controller.reset_size_and_stripes
        expect(controller.size_choice).to eq(:custom_size)
      end
    end

    context "if the lv type is not set to thin" do
      before do
        controller.lv_type = Y2Storage::LvType::THIN_POOL
      end

      it "sets size to nil" do
        controller.reset_size_and_stripes
        expect(controller.size).to be_nil
      end

      it "sets size choice to max size" do
        controller.reset_size_and_stripes
        expect(controller.size_choice).to eq(:max_size)
      end
    end
  end

  describe "#lv_can_be_formatted?" do
    before do
      allow(controller).to receive(:lv).and_return(lv)
    end

    context "if there is no lv" do
      let(:lv) { nil }

      it "returns false" do
        expect(controller.lv).to be_nil
        expect(controller.lv_can_be_formatted?).to eq(false)
      end
    end

    context "if the lv is a normal volume" do
      let(:lv) { instance_double(Y2Storage::LvmLv, lv_type: Y2Storage::LvType::NORMAL) }

      it "returns true" do
        expect(controller.lv_can_be_formatted?).to eq(true)
      end
    end

    context "if the lv is a thin pool" do
      let(:lv) { instance_double(Y2Storage::LvmLv, lv_type: Y2Storage::LvType::THIN_POOL) }

      it "returns false" do
        expect(controller.lv_can_be_formatted?).to eq(false)
      end
    end

    context "if the lv is a thin volume" do
      let(:lv) { instance_double(Y2Storage::LvmLv, lv_type: Y2Storage::LvType::THIN) }

      it "returns true" do
        expect(controller.lv_can_be_formatted?).to eq(true)
      end
    end
  end

  describe "#lv_can_be_added?" do
    before do
      allow(controller).to receive(:vg).and_return(vg)
      allow(vg).to receive(:number_of_free_extents).and_return(free_extents)
    end

    context "if there is free space" do
      let(:free_extents) { 10 }

      it "returns true" do
        expect(controller.lv_can_be_added?).to eq(true)
      end
    end

    context "if there is no free space" do
      let(:free_extents) { 0 }

      it "returns false" do
        expect(controller.lv_can_be_added?).to eq(false)
      end
    end
  end

  describe "#thin_lv_can_be_added?" do
    context "if there is no thin pool in the volume group" do
      it "returns false" do
        expect(controller.thin_lv_can_be_added?).to eq(false)
      end
    end

    context "if there are thin pools in the volume group" do
      before do
        create_thin_provisioning(vg)
      end

      it "returns true" do
        expect(controller.thin_lv_can_be_added?).to eq(true)
      end
    end
  end

  describe "#available_thin_pools" do
    context "if there is no thin pool in the volume group" do
      it "returns an empty list" do
        expect(controller.available_thin_pools).to be_empty
      end
    end

    context "if there are thin pools in the volume group" do
      before do
        create_thin_provisioning(vg)
      end

      it "returns a list of logical volumes" do
        expect(controller.available_thin_pools).to all(be_a(Y2Storage::LvmLv))
      end

      it "contains all thin pools" do
        expect(controller.available_thin_pools.map(&:name)).to contain_exactly(
          "/dev/vg0/pool1",
          "/dev/vg0/pool2"
        )
      end
    end
  end

  describe "#free_extents" do
    it "returns the number of extents of the editing vg" do
      allow(controller).to receive(:vg).and_return(vg)
      allow(vg).to receive(:number_of_free_extents).and_return(10)

      expect(controller.free_extents).to eq(10)
    end
  end

  describe "#min_size" do
    it "returns the extent size of the editing vg" do
      allow(controller).to receive(:vg).and_return(vg)
      allow(vg).to receive(:extent_size).and_return(1.MiB)

      expect(controller.min_size).to eq(1.MiB)
    end
  end

  describe "#max_size" do
    before do
      allow(controller).to receive(:lv_type).and_return(lv_type)
    end

    context "if the stored lv type is not thin" do
      let(:lv_type) { Y2Storage::LvType::NORMAL }

      before do
        allow(controller).to receive(:vg).and_return(vg)
        allow(vg).to receive(:max_size_for_lvm_lv).and_return(max_size)
      end

      let(:max_size) { 10.GiB }

      it "returns the max size for the given lv type in the current vg" do
        expect(controller.max_size).to eq(max_size)
      end
    end

    context "if the stored lv type is thin" do
      let(:lv_type) { Y2Storage::LvType::THIN }

      before do
        allow(controller).to receive(:thin_pool).and_return(thin_pool)
        allow(thin_pool).to receive(:max_size_for_lvm_lv)
          .with(Y2Storage::LvType::THIN).and_return(max_size)
      end

      let(:thin_pool) { instance_double(Y2Storage::LvmLv) }

      let(:max_size) { 100.GiB }

      it "returns the max size for a thin volume in the given thin pool" do
        expect(controller.max_size).to eq(max_size)
      end
    end
  end

  describe "#stripes_number_options" do
    before do
      allow(controller).to receive(:vg).and_return(vg)
    end

    let(:vg) { double("LvmVg", vg_name: "vg0", lvm_pvs: pvs) }

    context "when the editing vg has no pvs" do
      let(:pvs) { [] }

      it "returns an empty list" do
        expect(controller.stripes_number_options).to be_empty
      end
    end

    context "when the editing vg has pvs" do
      let(:pvs) { [double("LvmPv"), double("LvmPv"), double("LvmPv"), double("LvmPv")] }

      it "returns a sorted list of numbers" do
        options = controller.stripes_number_options

        expect(options).to all(be_a(Integer))
        expect(options).to eq(options.sort)
      end

      it "includes all values between 1 and the number of pvs in the editing vg" do
        expected_options = (1..vg.lvm_pvs.size).to_a
        expect(controller.stripes_number_options).to eq(expected_options)
      end
    end
  end

  describe "#stripes_size_options" do
    before do
      allow(controller).to receive(:vg).and_return(vg)
    end

    let(:vg) { double("LvmVg", vg_name: "vg0", extent_size: extent_size) }

    context "when the editing vg extend size is less than 4 KiB" do
      let(:extent_size) { 1.KiB }

      it "returns a list only with 4 KiB" do
        expect(controller.stripes_size_options).to eq([4.KiB])
      end
    end

    context "when the editing vg extend size is not less than 4 KiB" do
      let(:extent_size) { 35.KiB }

      it "returns a sorted list of DiskSize" do
        options = controller.stripes_size_options
        expect(options).to all(be_a(Y2Storage::DiskSize))
        expect(options).to eq(options.sort)
      end

      it "includes all power of two between 4 KiB and the vg extent size" do
        expected_options = [4.KiB, 8.KiB, 16.KiB, 32.KiB]
        expect(controller.stripes_size_options).to eq(expected_options)
      end
    end
  end

  describe "#name_errors" do
    let(:errors) { controller.name_errors(name) }

    context "when the name is valid" do
      let(:name) { "vg0" }

      it "returns an empty list" do
        expect(errors).to be_empty
      end
    end

    context "when the name is not given" do
      let(:name) { "" }

      it "contains an error for empty name" do
        expect(errors).to include(/Enter a name/)
      end
    end

    context "when the name is too long" do
      let(:name) { "a" * 129 }

      it "contains an error for too long name" do
        expect(errors).to include(/is longer/)
      end
    end

    context "when the name has unallowed characters" do
      let(:name) { "vg$0" }

      it "contains an error for illegal characters" do
        expect(errors).to include(/illegal characters/)
      end
    end

    context "when already exists a lv with that name in the current vg" do
      let(:name) { "lv1" }

      it "contains an error for used name" do
        expect(errors).to include(/already exists/)
      end
    end
  end

  describe "#wizard_title" do
    it "returns a string containing the vg name" do
      expect(controller.wizard_title).to be_a String
      expect(controller.wizard_title).to include vg_name
    end
  end
end
