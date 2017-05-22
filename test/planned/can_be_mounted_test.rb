#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

describe Y2Storage::Planned::CanBeMounted do

  # Dummy class to test the mixin
  class MountableDevice
    include Y2Storage::Planned::CanBeMounted

    def initialize(mount_point)
      initialize_can_be_mounted
      self.mount_point = mount_point
    end
  end

  describe "#shadowed?" do
    let(:other) { ["/home", "/boot", "/opt", "/var/log"] }

    it "detects shadowing a /home subvolume with /home" do
      expect(MountableDevice.new("/home").shadowed?(other)).to eq true
    end

    it "detects shadowing the /boot/something/else subvolume with /home" do
      expect(MountableDevice.new("/boot/xy/myarch").shadowed?(other)).to eq true
    end

    it "does not report a false positive for shadowing a /booting/xy subvolume with /boot" do
      expect(MountableDevice.new("/booting/xy").shadowed?(other)).to eq false
    end

    it "does not report a false positive for shadowing a /var subvolume with /var/log" do
      expect(MountableDevice.new("/var").shadowed?(other)).to eq false
    end

    it "handles a nonexistent mount point well" do
      expect(MountableDevice.new("/wrglbrmpf").shadowed?(other)).to eq false
    end

    it "handles an empty mount point well" do
      expect(MountableDevice.new("").shadowed?(other)).to eq false
    end

    it "handles a nil mount point well" do
      expect(MountableDevice.new(nil).shadowed?(other)).to eq false
    end

    it "returns false when the list of other mountpoints is empty" do
      expect(MountableDevice.new("/xy").shadowed?([])).to eq false
    end

    it "returns false when the list of other mountpoints is nil" do
      expect(MountableDevice.new("/xy").shadowed?(nil)).to eq false
    end
  end
end
