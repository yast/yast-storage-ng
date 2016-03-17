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

require_relative "../spec_helper"
require "storage"
require "storage/proposal"
require "storage/fake_probing"
require "storage/fake_device_factory"
require "storage/devicegraph_query"
require "storage/refinements/size_casts"

describe Yast::Storage::Proposal::PartitionCreator do
  describe "#create_partitions" do
    using Yast::Storage::Refinements::SizeCasts

    def input_file_for(name)
      File.join(DATA_PATH, "input", "#{name}.yml")
    end

    def fake_scenario(scenario)
      @fake_probing = Yast::Storage::FakeProbing.new
      devicegraph = @fake_probing.devicegraph
      Yast::Storage::FakeDeviceFactory.load_yaml_file(devicegraph, input_file_for(scenario))
    end

    before do
      fake_scenario(scenario)
      allow(analyzer).to receive(:candidate_disks).and_return candidate_disks
    end
    
    let(:settings) { Yast::Storage::Proposal::Settings.new }
    let(:analyzer) { instance_double("Yast::Storage::DiskAnalyzer") }
    let(:scenario) { "empty_hard_disk_50GiB" }
    let(:candidate_disks) { ["/dev/sda"] }
    let(:target_size) { :desired }

    let(:root_volume) { Yast::Storage::PlannedVolume.new("/", ::Storage::FsType_EXT4) }
    let(:home_volume) { Yast::Storage::PlannedVolume.new("/home", ::Storage::FsType_EXT4) }
    let(:swap_volume) { Yast::Storage::PlannedVolume.new("swap", ::Storage::FsType_EXT4) }
    let(:volumes) { Yast::Storage::PlannedVolumesList.new([root_volume, home_volume, swap_volume]) }

    subject(:creator) { described_class.new(@fake_probing.devicegraph, analyzer, settings) }

    context "when the exact space is available" do
      before do
        root_volume.desired = 20.GiB
        home_volume.desired = 20.GiB
        swap_volume.desired = 10.GiB
      end
      
      it "creates partitions matching the volume sizes" do
        result = creator.create_partitions(volumes, target_size)
        query = Yast::Storage::DevicegraphQuery.new(result)
        expect(query.partitions).to contain_exactly(
          an_object_with_fields(mountpoint: "/", size: 20.GiB),
          an_object_with_fields(mountpoint: "/home", size: 20.GiB),
          an_object_with_fields(mountpoint: "swap", size: 10.GiB)
        )
      end
    end

    context "when some extra space is available" do
      before do
        root_volume.desired = 20.GiB
        root_volume.weight = 1
        home_volume.desired = 20.GiB
        home_volume.weight = 2
        swap_volume.desired = 1.GiB
        swap_volume.max_size = 1.GiB
      end

      it "distributes the extra space" do
        result = creator.create_partitions(volumes, target_size)
        query = Yast::Storage::DevicegraphQuery.new(result)
        # FIXME: actually I wouldn't have expected these values, but 23GiB and 26GiB
        expect(query.partitions).to contain_exactly(
          an_object_with_fields(mountpoint: "/", size_k: 25015296),
          an_object_with_fields(mountpoint: "/home", size_k: 26363904),
          an_object_with_fields(mountpoint: "swap", size: 1.GiB)
        )
      end
    end
  end
end
