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

require_relative "../spec_helper"
require "y2storage"

describe Y2Storage::PartitionTables::Gpt do
  before do
    fake_scenario("empty_hard_disk_50GiB")
  end

  let(:disk) { Y2Storage::Disk.find_by_name(fake_devicegraph, "/dev/sda") }
  let(:partition_table_type) { Y2Storage::PartitionTables::Type.find(:gpt) }

  subject { disk.create_partition_table(partition_table_type) }

  describe "#partition_id_for" do
    it "uses the WINDOWS_BASIC_DATA partition id for WINDOWS_BASIC_DATA" do
      p_id = Y2Storage::PartitionId::WINDOWS_BASIC_DATA
      expect(subject.partition_id_for(p_id)).to eq p_id
    end

    it "uses the MICROSOFT_RESERVED partition id for MICROSOFT_RESERVED" do
      p_id = Y2Storage::PartitionId::MICROSOFT_RESERVED
      expect(subject.partition_id_for(p_id)).to eq p_id
    end

    it "uses the SWAP partition id for SWAP" do
      p_id = Y2Storage::PartitionId::SWAP
      expect(subject.partition_id_for(p_id)).to eq Y2Storage::PartitionId::SWAP
    end

    it "uses the WINDOWS_BASIC_DATA partition id for NTFS" do
      p_id = Y2Storage::PartitionId::NTFS
      expect(subject.partition_id_for(p_id)).to eq Y2Storage::PartitionId::WINDOWS_BASIC_DATA
    end

    it "uses the WINDOWS_BASIC_DATA partition id for DOS32" do
      p_id = Y2Storage::PartitionId::DOS32
      expect(subject.partition_id_for(p_id)).to eq Y2Storage::PartitionId::WINDOWS_BASIC_DATA
    end
  end
end
