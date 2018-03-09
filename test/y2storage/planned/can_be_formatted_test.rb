#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

describe Y2Storage::Planned::CanBeFormatted do
  using Y2Storage::Refinements::SizeCasts

  # Dummy class to test the mixing
  class FormattableDevice < Y2Storage::Planned::Device
    include Y2Storage::Planned::CanBeMounted
    include Y2Storage::Planned::CanBeFormatted

    def initialize
      super
      initialize_can_be_formatted
      initialize_can_be_mounted
    end
  end

  subject(:planned) { FormattableDevice.new }

  describe "#format!" do
    let(:filesystem_type) { Y2Storage::Filesystems::Type::BTRFS }
    let(:blk_device) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, device_name) }
    let(:device_name) { "/dev/sda2" }

    before do
      fake_scenario("windows-linux-free-pc")
      planned.filesystem_type = filesystem_type
    end

    it "creates a filesystem of the given type" do
      planned.format!(blk_device)
      expect(blk_device.filesystem.type).to eq(filesystem_type)
    end

    context "when filesystem type is not defined" do
      let(:filesystem_type) { nil }

      it "does not format the device" do
        planned.format!(blk_device)
        expect(blk_device.filesystem.type).to eq(Y2Storage::Filesystems::Type::SWAP)
      end
    end
  end
end
