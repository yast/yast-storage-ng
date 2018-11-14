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

describe Y2Storage::Planned::CanBeMdMember do

  # Dummy class to test the mixin
  class MdMemberDevice < Y2Storage::Planned::Device
    include Y2Storage::Planned::CanBeMdMember

    def initialize
      super
      initialize_can_be_md_member
    end
  end

  subject(:planned) { MdMemberDevice.new }

  describe "#md_member?" do
    context "when the device has a RAID name" do
      before do
        planned.raid_name = "/dev/md0"
      end

      it "returns true" do
        expect(planned.md_member?).to eq(true)
      end
    end

    context "when the device does not have a RAID name" do
      it "returns false" do
        expect(planned.md_member?).to eq(false)
      end
    end
  end
end
