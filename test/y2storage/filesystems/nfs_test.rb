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

describe Y2Storage::Filesystems::Nfs do

  before do
    fake_scenario("nfs1.xml")
  end
  subject(:filesystem) { fake_devicegraph.find_device(42) }

  describe "#match_fstab_spec?" do
    it "returns true for the correct NFS spec" do
      expect(filesystem.match_fstab_spec?("srv:/home/a")).to eq true
    end

    it "returns true if the spec contains a trailing slash" do
      expect(filesystem.match_fstab_spec?("srv:/home/a/")).to eq true
    end

    it "returns false for any other NFS spec" do
      expect(filesystem.match_fstab_spec?("srv2:/home/b")).to eq false
    end

    it "returns false for any spec starting with LABEL=" do
      expect(filesystem.match_fstab_spec?("LABEL=label")).to eq false
    end

    it "returns false for any spec starting with UUID=" do
      expect(filesystem.match_fstab_spec?("UUID=0000-00-00")).to eq false
    end

    it "returns false for any device name" do
      expect(filesystem.match_fstab_spec?("/dev/sda1")).to eq false
      expect(filesystem.match_fstab_spec?("/dev/disk/by-label/whatever")).to eq false
    end
  end
end
