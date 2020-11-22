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

  describe "#value_for" do
    context "when given device is a fstab entry" do
      let(:btrfs) { Y2Storage::Filesystems::Type::BTRFS }
      let(:home_fstab_entry) { fstab_entry("/dev/sda2", "/home", btrfs, ["subvol=@/home"], 0, 0) }

      it "returns its mount point" do
        expect(Bidi.bidi_strip(subject.value_for(home_fstab_entry))).to eq("/home")
      end
    end

    context "when given device is formatted and mounted" do
      let(:device_name) { "/dev/sda3" }

      it "returns its mount point" do
        expect(subject.value_for(device)).to eq("swap")
      end
    end

    context "when given device is not mounted" do
      let(:device_name) { "/dev/sda1" }

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

    context "when given device is a filesystem" do
      let(:device) { devicegraph.find_by_name("/dev/sdb1").filesystem }

      it "returns its mount point" do
        expect(subject.value_for(device)).to eq("/test")
      end
    end

    context "when given device is a Btrfs subvolume" do
      let(:filesystem) { devicegraph.find_by_name("/dev/sdb1").filesystem }
      let(:device) { filesystem.btrfs_subvolumes.find { |s| s.path == "sub1" } }

      it "returns its mount point" do
        expect(subject.value_for(device)).to eq("/test/sub1")
      end
    end

    context "when the mount point is active" do
      let(:scenario) { "nfs1.xml" }
      let(:device) do
        Y2Storage::Filesystems::Nfs.find_by_server_and_path(devicegraph, "srv2", "/home/b")
      end

      it "returns the mount path without an asterisk sign" do
        expect(Bidi.bidi_strip(subject.value_for(device))).to eq("/test2")
      end
    end

    context "when the mount point is not active" do
      let(:scenario) { "nfs1.xml" }
      let(:device) do
        Y2Storage::Filesystems::Nfs.find_by_server_and_path(devicegraph, "srv", "/home/a")
      end

      it "returns the mount path including an asterisk sign" do
        expect(Bidi.bidi_strip(subject.value_for(device))).to eq("/test1 *")
      end
    end

    context "(not only) when the mount path contains right to left (RTL) characters" do
      let(:scenario) { "bidi.yml" }
      let(:device_name) { "/dev/sdb1" }

      it "returns the mount path with appropriate bidi control characters" do
        allow(subject).to receive(:bidi_supported?).and_return(true)

        # \u20xx are the control characters
        # \u06xx are Arabic letters
        expect(subject.value_for(device)).to eq("\u2066" \
                                                "/\u2068\u0641\u064A\u062F\u064A\u0648\u2069" \
                                                "/\u2068\u0642\u062F\u064A\u0645\u0629\u2069" \
                                                "\u2069")
      end
    end
  end
end
