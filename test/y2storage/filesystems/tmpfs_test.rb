#!/usr/bin/env rspec
# Copyright (c) [2020] SUSE LLC
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

describe Y2Storage::Filesystems::Tmpfs do
  before do
    Y2Storage::StorageManager.create_test_instance
  end
  subject(:filesystem) { described_class.create(fake_devicegraph) }

  describe "#size" do
    it "returns the size specified as mount option" do
      filesystem.mount_path = "/tmp"
      filesystem.mount_point.mount_options = ["rw", "size=128M", "noatime"]

      expect(filesystem.size).to eq Y2Storage::DiskSize.MiB(128)
    end

    it "returns zero if there is no mount point" do
      expect(filesystem.size).to eq Y2Storage::DiskSize.zero
    end

    it "returns zero if there are no mount options" do
      filesystem.mount_path = "/tmp"
      expect(filesystem.size).to eq Y2Storage::DiskSize.zero
    end
  end
end
