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

  subject { described_class.new(device) }

  let(:device) { Y2Partitioner::DeviceGraphs.instance.current.find_by_name(device_name) }

  describe "#restore_from_checkpoint" do
    let(:device_name) { "/dev/sda1" }

    context "when restoring a device used by filesystem itself" do
      let(:filesystem) { device.direct_blk_filesystem }

      before do
        # same sequence as in Controllers::BtrfsDevices.remove_device
        filesystem.remove_device(device)
      end

      it "does not raise an exception" do
        expect { subject.restore_from_checkpoint }.to_not raise_error
      end

      it "does not remove the filesystem" do
        sid = filesystem.sid

        subject.restore_from_checkpoint

        expect(Y2Partitioner::DeviceGraphs.instance.current.find_device(sid)).to_not be_nil
      end
    end
  end

end
