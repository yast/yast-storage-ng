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
require "y2storage/hwinfo_reader"

describe Y2Storage::HWInfoReader do
  let(:reader) { described_class.instance }
  let(:hwinfo_output) { File.read(File.join(DATA_PATH, "hwinfo.txt")) }

  describe "#for_device" do
    before do
      allow(Yast::Execute).to receive(:on_target!)
        .with(/hwinfo/, anything, anything, anything).and_return(hwinfo_output)
      reader.reset!
    end

    it "returns hardware information for the given device" do
      data = reader.for_device("/dev/sda")
      expect(data).to be_a(OpenStruct)
      expect(data.to_h)
        .to include(bus:              "IDE",
                    unique_id:        "3OOL.7kkY9irDFZ4",
                    driver_modules:   ["ahci"],
                    driver:           ["ahci", "sd"],
                    geometry_logical: "CHS 121601/255/63")
    end

    it "retrieves hardware information from hwinfo" do
      expect(Yast::Execute).to receive(:on_target!)
        .with("/usr/sbin/hwinfo", "--disk", "--listmd", stdout: :capture)
        .and_return(hwinfo_output)
      reader.for_device("/dev/sda")
    end

    it "caches hardware information" do
      expect(Yast::Execute).to receive(:on_target!)
        .with("/usr/sbin/hwinfo", "--disk", "--listmd", stdout: :capture)
        .and_return(hwinfo_output)
        .once
      reader.for_device("/dev/sda")
      reader.for_device("/dev/sda")
    end
  end
end
