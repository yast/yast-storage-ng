#!/usr/bin/env rspec
# Copyright (c) [2019] SUSE LLC
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

require_relative "test_helper"

require "y2partitioner/blk_device_restorer"

describe Y2Partitioner::BlkDeviceRestorer do

  let(:devicegraph) { "trivial_btrfs" }

  before do
    devicegraph_stub(devicegraph)
  end

  describe "#restore_from_checkpoint" do
    it "does not crash when restoring device used by filesystem itself" do
      device = Y2Partitioner::DeviceGraphs.instance.current.find_by_name("/dev/sda1")
      filesystem = device.direct_blk_filesystem

      # same sequence as in Controllers::BtrfsDevices.remove_device
      filesystem.remove_device(device)
      Y2Partitioner::BlkDeviceRestorer.new(device).restore_from_checkpoint
    end
  end

end
