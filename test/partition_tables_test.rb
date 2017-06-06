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

require_relative "spec_helper"
require "y2storage"

describe Y2Storage::PartitionTables::Base do
  before do
    fake_scenario("mixed_disks")
  end

  # Testing this because it's a nice example of usage of the Ruby wrapper
  # and because it was broken at some point
  describe "#inspect" do
    subject(:ptable) { Y2Storage::Disk.find_by_name(fake_devicegraph, "/dev/sdb").partition_table }

    it "includes the partition table type" do
      expect(ptable.inspect).to include "Msdos"
    end

    it "includes all the partitions" do
      expect(ptable.inspect).to include "Partition /dev/sdb1 4 GiB"
      expect(ptable.inspect).to include "Partition /dev/sdb2 60 GiB"
      expect(ptable.inspect).to include "Partition /dev/sdb3 60 GiB"
      expect(ptable.inspect).to include "Partition /dev/sdb4 810 GiB"
      expect(ptable.inspect).to include "Partition /dev/sdb5 300 GiB"
      expect(ptable.inspect).to include "Partition /dev/sdb6 500 GiB"
      expect(ptable.inspect).to include "Partition /dev/sdb7 10237 MiB"
    end
  end
end
