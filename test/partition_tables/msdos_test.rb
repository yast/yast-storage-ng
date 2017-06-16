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

describe Y2Storage::PartitionTables::Msdos do
  before do
    fake_scenario("empty_hard_disk_50GiB")
  end

  let(:disk) { Y2Storage::Disk.find_by_name(fake_devicegraph, "/dev/sda") }
  let(:partition_table_type) { Y2Storage::PartitionTables::Type.find(:msdos) }

  subject { disk.create_partition_table(partition_table_type) }

  describe "#partition_id_for" do
    it "uses the same partition id" do
      swap = Y2Storage::PartitionId::SWAP
      expect(subject.partition_id_for(swap)).to eq swap
    end
  end
end
