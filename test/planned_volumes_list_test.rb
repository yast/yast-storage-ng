#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

describe Y2Storage::PlannedVolumesList do
  using Y2Storage::Refinements::SizeCasts

  before(:all) { skip }

  def vol(mount_point, size, min_size, max_size)
    vol = Y2Storage::PlannedVolume.new(mount_point)
    vol.disk_size = size
    vol.min = min_size
    vol.max = max_size
    vol
  end

  describe "#sort_by_attr" do
    let(:vol1) { vol("/vol1", 100.MiB, 1.GiB, 2.GiB) }
    let(:vol2) { vol("/vol2", nil,     1.GiB, 2.GiB) }
    let(:vol3) { vol("/vol3", 100.GiB, 2.GiB, 4.GiB) }
    let(:vol4) { vol("/vol4", nil,     1.GiB, 3.GiB) }

    subject { described_class.new([vol1, vol2, vol3, vol4]) }

    it "returns an array" do
      expect(subject.sort_by_attr(:disk_size)).to be_a Array
    end

    it "raises an error if the attribute does not exists" do
      expect { subject.sort_by_attr(:none) }.to raise_error NoMethodError
    end

    it "sorts ascending with nils at the end by default" do
      expect(subject.sort_by_attr(:disk_size).map(&:disk_size))
        .to eq [100.MiB, 100.GiB, nil, nil]
    end

    it "can sort in descending order" do
      expect(subject.sort_by_attr(:disk_size, descending: true).map(&:disk_size))
        .to eq [100.GiB, 100.MiB, nil, nil]
    end

    it "can sort nils at start" do
      expect(subject.sort_by_attr(:disk_size, nils_first: true).map(&:disk_size))
        .to eq [nil, nil, 100.MiB, 100.GiB]
    end

    it "uses the next attribute in the list to break ties" do
      result = subject.sort_by_attr(:min, :max, :disk_size, nils_first: true)
      expect(result).to eq [vol2, vol1, vol4, vol3]
    end

    it "respects the original order in case of full tie" do
      expect(subject.sort_by_attr(:min_disk_size)).to eq [vol1, vol2, vol4, vol3]
    end
  end

  describe "#distribute_space" do
    let(:vol1) { planned_vol(mount_point: "/1", desired: 1.GiB, weight: 1) }
    let(:vol2) { planned_vol(mount_point: "/2", desired: 1.GiB, weight: 1) }

    subject(:list) { described_class.new([vol1, vol2]) }

    # Regression test. There was a bug and it tried to assign 501 extra bytes
    # to each volume (one more byte than available)
    it "does not distribute more space than available" do
      space = 2.GiB + Y2Storage::DiskSize.new(1001)
      result = list.distribute_space(space)
      expect(result).to contain_exactly(
        an_object_having_attributes(disk_size: 1.GiB + Y2Storage::DiskSize.new(501)),
        an_object_having_attributes(disk_size: 1.GiB + Y2Storage::DiskSize.new(500))
      )
    end
  end

  describe "#enforced_last" do
    let(:big_vol1) { planned_vol(type: :vfat, desired: 10.MiB) }
    let(:big_vol2) { planned_vol(type: :vfat, desired: 10.MiB) }
    let(:small_vol) { planned_vol(type: :vfat, desired: 1.MiB + 512.KiB) }

    subject(:list) { described_class.new([big_vol1, small_vol, big_vol2]) }

    it "returns nil if all the volumes are divisible by min_grain" do
      size = 21.MiB + 512.KiB
      min_grain = 512.KiB
      expect(list.enforced_last(size, min_grain)).to be_nil
    end

    it "returns nil if the space is big enough for any order" do
      size = 22.MiB
      min_grain = 1.MiB
      expect(list.enforced_last(size, min_grain)).to be_nil
    end

    it "returns nil if the volumes don't fit into the space" do
      size = 21.MiB
      min_grain = 1.MiB
      expect(list.enforced_last(size, min_grain)).to be_nil
    end

    it "returns the volume that must be placed at the end" do
      size = 21.MiB + 512.KiB
      min_grain = 1.MiB
      expect(list.enforced_last(size, min_grain)).to eq small_vol
    end
  end
end
