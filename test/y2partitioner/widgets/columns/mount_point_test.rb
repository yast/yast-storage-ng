#!/usr/bin/env rspec

# Copyright (c) [2020-2022] SUSE LLC
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
require "y2storage/filesystems/legacy_nfs"

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
    shared_examples "device mount point" do |mount_path|
      it "returns its mount point" do
        expect(subject.value_for(device)).to eq(mount_path)
      end

      context "when the mount point is active" do
        before do
          allow_any_instance_of(Y2Storage::MountPoint).to receive(:active?).and_return(true)
        end

        it "returns the mount path without an asterisk sign" do
          value = BidiMarkup.bidi_strip(subject.value_for(device))

          expect(value).to eq(mount_path)
          expect(value).to_not include("*")
        end
      end

      context "when the mount point is not active" do
        before do
          allow_any_instance_of(Y2Storage::MountPoint).to receive(:active?).and_return(false)
        end

        it "returns the mount path including an asterisk sign" do
          value = BidiMarkup.bidi_strip(subject.value_for(device))

          expect(value).to eq("#{mount_path} *")
        end
      end
    end

    context "when the given device is formatted and mounted" do
      let(:device_name) { "/dev/sda3" }

      include_examples "device mount point", "swap"
    end

    context "when the given device is a filesystem" do
      let(:device) { devicegraph.find_by_name("/dev/sdb1").filesystem }

      include_examples "device mount point", "/test"
    end

    context "when the given device is a Btrfs subvolume" do
      let(:filesystem) { devicegraph.find_by_name("/dev/sdb1").filesystem }
      let(:device) { filesystem.btrfs_subvolumes.find { |s| s.path == "sub1" } }

      include_examples "device mount point", "/test/sub1"
    end

    context "when the given device is not mounted" do
      let(:device_name) { "/dev/sda1" }

      it "returns an empty string" do
        expect(subject.value_for(device)).to eq("")
      end
    end

    context "when the given device is part of a multidevice filesystem" do
      let(:device_name) { "/dev/sdb1" }

      it "returns an empty string" do
        expect(subject.value_for(device)).to eq("")
      end
    end

    context "when the given device is a fstab entry" do
      let(:btrfs) { Y2Storage::Filesystems::Type::BTRFS }
      let(:home_fstab_entry) { fstab_entry("/dev/sda2", "/home", btrfs, ["subvol=@/home"], 0, 0) }

      it "returns its mount point" do
        expect(BidiMarkup.bidi_strip(subject.value_for(home_fstab_entry))).to eq("/home")
      end
    end

    context "when the given device is a legacy NFS" do
      let(:device) { Y2Storage::Filesystems::LegacyNfs.new }

      before do
        device.server = "test"
        device.path = "/test"
        device.mountpoint = "/mnt/test"
        device.active = active
      end

      let(:active) { true }

      it "returns its mount point" do
        expect(subject.value_for(device)).to eq("/mnt/test")
      end

      context "when the mount point is not active" do
        let(:active) { false }

        it "returns its mount point including an asterisk sign" do
          expect(subject.value_for(device)).to eq("/mnt/test *")
        end
      end
    end

    describe "bidi right to left (RTL) handling" do
      let(:scenario) { "bidi.yml" }
      before do
        allow(subject).to receive(:bidi_supported?).and_return(true)
      end
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

      context "when the path is root /" do
        let(:device_name) { "/dev/sda" }

        it "returns the mount path wrapped with LTR Isolate" do
          expect(subject.value_for(device)).to eq("\u2066/\u2069")
        end
      end
    end
  end
end
