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
require "y2partitioner/sequences/controllers/lvm_lv"

describe Y2Partitioner::Sequences::Controllers::LvmLv do
  using Y2Storage::Refinements::SizeCasts

  subject(:controller) { described_class.new(vg) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, vg_name) }

  let(:vg_name) { "vg0" }

  before do
    devicegraph_stub("lvm-two-vgs.yml")

    allow(controller).to receive(:lv_name).and_return(lv_name)
    allow(controller).to receive(:size).and_return(size)
    allow(controller).to receive(:stripes_number).and_return(stripes_number)
    allow(controller).to receive(:stripes_size).and_return(stripes_size)
  end

  let(:lv_name) { nil }

  let(:size) { nil }

  let(:stripes_number) { nil }

  let(:stripes_size) { nil }

  describe "#vg" do
    it "returns a Y2Storage::LvmVg" do
      expect(subject.vg).to be_a(Y2Storage::LvmVg)
    end

    it "returns the currently editing vg" do
      expect(subject.vg).to eq(vg)
    end
  end

  describe "#create_lv" do
    let(:lv_name) { "lv3" }

    let(:size) { 3.GiB }

    let(:stripes_number) { 2 }

    let(:stripes_size) { 16.KiB }

    it "creates a new lv in the editing vg" do
      expect(controller.vg.lvm_lvs.size).to eq(2)
      controller.create_lv
      expect(controller.vg.lvm_lvs.size).to eq(3)
    end

    it "creates a new lv with indicated values" do
      expect(controller.vg.lvm_lvs.map(&:lv_name)).to_not include(lv_name)

      controller.create_lv
      lv = controller.vg.lvm_lvs.find { |l| l.lv_name == lv_name }

      expect(lv.lv_name).to eq(lv_name)
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
  end

  describe "#delete_lv" do
    context "when a lv has not been created" do
      it "does not modify the editing vg" do
        lvs = controller.vg.lvm_lvs
        controller.delete_lv
        expect(controller.vg.lvm_lvs).to eq(lvs)
      end
    end

    context "when a lv has been created" do
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
    it "returns the availabe space of the editing vg" do
      allow(controller).to receive(:vg).and_return(vg)
      allow(vg).to receive(:available_space).and_return(10.GiB)

      expect(controller.max_size).to eq(10.GiB)
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

  describe "#error_for_lv_name" do
    let(:errors) { controller.error_for_lv_name(name) }

    context "when the name is valid" do
      let(:name) { "vg0" }

      it "returns nil" do
        expect(errors).to be_nil
      end
    end

    context "when the name is too long" do
      let(:name) { "a" * 129 }

      it "returns a string with the proper error message" do
        expect(errors).to include "is longer"
      end
    end

    context "when the name has unallowed characters" do
      let(:name) { "vg$0" }

      it "returns a string with the proper error message" do
        expect(errors).to include "illegal characters"
      end
    end
  end

  describe "#lv_name_in_use?" do
    context "when already exists a lv with that name in the editing vg" do
      let(:name) { "lv1" }

      it "returns true" do
        expect(controller.lv_name_in_use?(name)).to be(true)
      end
    end

    context "when already exists a lv with that name in the editing vg" do
      let(:name) { "lv10" }

      it "returns false" do
        expect(controller.lv_name_in_use?(name)).to be(false)
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
