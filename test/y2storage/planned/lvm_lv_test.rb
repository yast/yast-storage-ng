#!/usr/bin/env rspec
#
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

require_relative "../spec_helper"
require "y2storage/planned"

describe Y2Storage::Planned::LvmLv do
  using Y2Storage::Refinements::SizeCasts

  subject(:lvm_lv) { described_class.new(mount_point) }

  let(:mount_point) { "/" }

  let(:volume_group) do
    instance_double(Y2Storage::LvmVg, size: 30.GiB, extent_size: 4.MiB)
  end

  describe "#initialize" do
    context "when creating a planned lv for a given mount point" do
      context "and the mount point is '/'" do
        let(:mount_point) { "/" }

        it "sets lv name to 'root'" do
          expect(subject.logical_volume_name).to eq("root")
        end
      end

      context "and the mount point is not '/'" do
        let(:mount_point) { "/var/lib/docker" }

        it "sets lv name based on mount point" do
          expect(subject.logical_volume_name).to eq("var_lib_docker")
        end
      end
    end

    context "when creating a planned lv without mount point" do
      let(:mount_point) { nil }

      it "does not set lv name" do
        expect(subject.logical_volume_name).to be_nil
      end
    end
  end

  describe "#size_in" do
    let(:lv_size) { 10.GiB }

    before do
      lvm_lv.size = lv_size
    end

    it "returns the logical volume size" do
      expect(lvm_lv.size_in(volume_group)).to eq(lv_size)
    end

    context "when size is a percentage" do
      before do
        lvm_lv.percent_size = 50
      end

      it "returns the size based on the volume group size" do
        expect(lvm_lv.size_in(volume_group)).to eq(15.GiB)
      end
    end
  end
end
