#!/usr/bin/env rspec
# encoding: utf-8

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

require_relative "../test_helper"

require "yast"
require "cwm/rspec"
require "y2partitioner/actions/controllers/btrfs_devices"
require "y2partitioner/widgets/btrfs_metadata_raid_level"

describe Y2Partitioner::Widgets::BtrfsMetadataRaidLevel do
  subject(:widget) { described_class.new(controller) }

  let(:controller) do
    Y2Partitioner::Actions::Controllers::BtrfsDevices.new
  end

  before do
    allow(Yast::UI).to receive(:QueryWidget).and_return :raid10
  end

  include_examples "CWM::ComboBox"

  describe "#handle" do
    it "sets the data raid level" do
      expect(controller).to receive(:metadata_raid_level=).with(Y2Storage::BtrfsRaidLevel::RAID10)

      widget.handle
    end
  end
end
