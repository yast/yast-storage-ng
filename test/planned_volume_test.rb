#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016-2017] SUSE LLC
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
require "storage"
require "y2storage"

describe Y2Storage::PlannedVolume do
  describe "#shadows?" do
    let(:other) { ["/home", "/boot", "/opt", "/var/log"] }

    it "detects shadowing /home with a /home subvolume" do
      expect(Y2Storage::PlannedVolume.shadows?("/home", other)).to be true
    end

    it "detects shadowing /boot with a /boot/something/else subvolume" do
      expect(Y2Storage::PlannedVolume.shadows?("/boot/xy/myarch", other)).to be true
    end

    it "does not report a false positive for shadowing /boot with a /booting/xy subvolume" do
      expect(Y2Storage::PlannedVolume.shadows?("/booting/xy", other)).to be false
    end

    it "does not report a false positive /var/log with a /var subvolume" do
      expect(Y2Storage::PlannedVolume.shadows?("/var", other)).to be false
    end

    it "handles a nonexistent mount point well" do
      expect(Y2Storage::PlannedVolume.shadows?("/wrglbrmpf", other)).to be false
    end

    it "handles an empty mount point well" do
      expect(Y2Storage::PlannedVolume.shadows?("", other)).to be false
    end

    it "handles an empty mount points list well" do
      expect(Y2Storage::PlannedVolume.shadows?("/xy", [])).to be false
    end

    it "handles a nil mount point well" do
      expect(Y2Storage::PlannedVolume.shadows?(nil, other)).to be false
    end

    it "handles a nil mount points list well" do
      expect(Y2Storage::PlannedVolume.shadows?("/xy", nil)).to be false
    end
  end
end
