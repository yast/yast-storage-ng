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

describe Y2Storage::Dasd do

  before do
    fake_scenario(scenario)
  end

  let(:scenario) { "empty_dasd_50GiB" }
  subject { Y2Storage::Dasd.find_by_name(fake_devicegraph, "/dev/sda") }

  describe "#usb?" do
    it "returns false" do
      expect(subject.usb?).to be_falsey
    end
  end

  describe "#preferred_ptable_type" do
    it "returns dasd" do
      expect(subject.preferred_ptable_type).to eq Y2Storage::PartitionTables::Type::DASD
    end
  end
end
