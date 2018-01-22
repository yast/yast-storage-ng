#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

require_relative "spec_helper"
require "y2storage"

describe Y2Storage::LvmLv do
  using Y2Storage::Refinements::SizeCasts

  before do
    fake_scenario("complex-lvm-encrypt")
  end

  describe "#resize" do
    subject(:lv) { fake_devicegraph.find_by_name("/dev/vg0/lv1") }

    before { allow(lv).to receive(:detect_resize_info).and_return resize_info }

    let(:resize_info) { double(Y2Storage::ResizeInfo, resize_ok?: ok, min_size: min, max_size: max) }
    let(:ok) { true }
    let(:min) { 1.GiB }
    let(:max) { 5.GiB }

    context "if the volume cannot be resized" do
      let(:ok) { false }

      it "does not modify the volume" do
        initial_size = lv.size
        lv.resize(4.5.GiB)
        expect(lv.size).to eq initial_size
      end
    end

    context "if the new size is bigger than the max resizing size" do
      context "and not divisible by the extent size" do
        let(:new_size) { 5.5.GiB - 1.MiB }

        it "sets the size of the volume to the max" do
          lv.resize(new_size)
          expect(lv.size).to eq max
        end
      end

      context "and divisible by the extent size" do
        let(:new_size) { 5.5.GiB }

        it "sets the size of the volume to the max" do
          lv.resize(new_size)
          expect(lv.size).to eq max
        end
      end
    end

    context "if the new size is smaller than the min resizing size" do
      context "and not divisible by the extent size" do
        let(:new_size) { 0.5.GiB - 1.MiB }

        it "sets the size of the volume to the min" do
          lv.resize(new_size)
          expect(lv.size).to eq min
        end
      end

      context "and divisible by the extent size" do
        let(:new_size) { 0.5.GiB }

        it "sets the size of the volume to the min" do
          lv.resize(new_size)
          expect(lv.size).to eq min
        end
      end
    end

    context "if the new size is within the resizing limits" do
      context "and not divisible by the extent size" do
        let(:new_size) { 2.5.GiB - 1.MiB }
        let(:extent_size) { lv.lvm_vg.extent_size }

        it "sets the size to a value divisible by the extent size" do
          expect(new_size.to_i.to_f % extent_size.to_i).to_not be_zero
          expect(lv.size.to_i.to_f % extent_size.to_i).to be_zero
        end

        it "sets the size to a value smaller than the requested" do
          lv.resize(new_size)
          expect(lv.size).to be < new_size
        end

        it "sets the size to closest possible value" do
          lv.resize(new_size)
          expect(new_size - lv.size).to be < extent_size
        end
      end

      context "and divisible by the extent size" do
        let(:new_size) { 2.5.GiB }

        it "sets the size of the volume to the requested size" do
          lv.resize(new_size)
          expect(lv.size).to eq new_size
        end
      end
    end
  end
end
