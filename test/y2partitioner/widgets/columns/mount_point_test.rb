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

require_relative "../../test_helper"
require_relative "./shared_examples"

require "y2partitioner/widgets/columns/mount_point"

describe Y2Partitioner::Widgets::Columns::MountPoint do
  subject { described_class.new }

  include_examples "Y2Partitioner::Widgets::Column"

  let(:scenario) { "btrfs2-devicegraph.xml" }
  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:device) { devicegraph.find_by_name(device_name) }

  before do
    devicegraph_stub(scenario)
  end

  describe "#values_for" do
    context "when given device is a fstab entry" do
      let(:btrfs) { Y2Storage::Filesystems::Type::BTRFS }
      let(:home_fstab_entry) { fstab_entry("/dev/sda2", "/home", btrfs, ["subvol=@/home"], 0, 0) }

      it "returns its mount point" do
        expect(subject.value_for(home_fstab_entry)).to eq("/home")
      end
    end

    context "when given device is a filesystem" do
      let(:device_name) { "/dev/sdb" }

      it "returns an empty string" do
        expect(subject.value_for(device)).to eq("")
      end
    end

    context "when given device is part of a multidevice filesystem" do
      let(:device_name) { "/dev/sdb1" }

      it "returns an empty string" do
        expect(subject.value_for(device)).to eq("")
      end
    end

    context "when the mount point is active" do
      let(:scenario) { "nfs1.xml" }
      let(:device) do
        Y2Storage::Filesystems::Nfs.find_by_server_and_path(devicegraph, "srv2", "/home/b")
      end

      it "returns the mount path without an asterisk sign" do
        expect(subject.value_for(device)).to eq("/test2")
      end
    end

    context "when the mount point is not active" do
      let(:scenario) { "nfs1.xml" }
      let(:device) do
        Y2Storage::Filesystems::Nfs.find_by_server_and_path(devicegraph, "srv", "/home/a")
      end

      it "returns the mount path including an asterkisk sign" do
        expect(subject.value_for(device)).to eq("/test1 *")
      end
    end
  end
end
