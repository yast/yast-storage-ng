#!/usr/bin/env rspec
# encoding: utf-8
#
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
require "y2storage/skip_list_value"

describe Y2Storage::SkipListValue do
  subject(:value) { Y2Storage::SkipListValue.new(disk) }

  let(:scenario) { "windows-linux-free-pc" }
  let(:disk) { Y2Storage::Disk.find_by_name(fake_devicegraph, "/dev/sda") }

  before do
    fake_scenario(scenario)
  end

  describe "#size_k" do
    it "returns the size in kilobytes" do
      expect(value.size_k).to eq(disk.size.to_i)
    end
  end

  describe "#device" do
    it "returns the full device name" do
      expect(value.device).to eq("/dev/sda")
    end
  end

  describe "#name" do
    it "returns the device name" do
      expect(value.name).to eq("sda")
    end
  end
end
