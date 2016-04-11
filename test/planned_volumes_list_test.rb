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
require "storage/planned_volumes_list"
require "storage/refinements/size_casts"

describe Yast::Storage::PlannedVolumesList do
  using Yast::Storage::Refinements::SizeCasts

  def vol(mount_point, size, min_size, max_size)
    vol = Yast::Storage::PlannedVolume.new(mount_point)
    vol.size = size
    vol.min_size = min_size
    vol.max_size = max_size
    vol
  end

  describe "#sort_by_attr" do
    let(:vol1) { vol("/vol1", 100.MiB, 1.GiB, 2.GiB) }
    let(:vol2) { vol("/vol2", nil,     1.GiB, 2.GiB) }
    let(:vol3) { vol("/vol3", 100.GiB, 2.GiB, 4.GiB) }
    let(:vol4) { vol("/vol4", nil,     1.GiB, 3.GiB) }

    subject { described_class.new([vol1, vol2, vol3, vol4]) }

    it "returns an array" do
      expect(subject.sort_by_attr(:size)).to be_a Array
    end

    it "raises an error if the attribute does not exists" do
      expect { subject.sort_by_attr(:none) }.to raise_error NoMethodError
    end

    it "sorts ascending with nils at the end by default" do
      expect(subject.sort_by_attr(:size).map(&:size))
        .to eq [100.MiB, 100.GiB, nil, nil]
    end

    it "can sort in descending order" do
      expect(subject.sort_by_attr(:size, descending: true).map(&:size))
        .to eq [100.GiB, 100.MiB, nil, nil]
    end

    it "can sort nils at start" do
      expect(subject.sort_by_attr(:size, nils_first: true).map(&:size))
        .to eq [nil, nil, 100.MiB, 100.GiB]
    end

    it "uses the next attribute in the list to break ties" do
      result = subject.sort_by_attr(:min_size, :max_size, :size, nils_first: true)
      expect(result).to eq [vol2, vol1, vol4, vol3]
    end

    it "respects the original order in case of full tie" do
      expect(subject.sort_by_attr(:min_size)).to eq [vol1, vol2, vol4, vol3]
    end
  end
end
