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

require_relative "../../test_helper"

require "y2partitioner/actions/controllers/fstabs"

describe Y2Partitioner::Actions::Controllers::Fstabs do
  def system_graph
    Y2Partitioner::DeviceGraphs.instance.system
  end

  def initial_graph
    Y2Partitioner::DeviceGraphs.instance.initial
  end

  # Note that current devicegraph can be replaced when importing mount points, so
  # the tests should not store devices belonging to current devicegraph. The first
  # version of current devicegraph could disappear, and a segmentation fault could
  # be produced when we try to use a device of that devicegraph.
  def current_graph
    Y2Partitioner::DeviceGraphs.instance.current
  end

  def use_device(device_name)
    device = system_graph.find_by_name(device_name)
    device.remove_descendants
    vg = Y2Storage::LvmVg.create(system_graph, "vg0")
    vg.add_lvm_pv(device)
  end

  def encrypt_device(device_name)
    device = system_graph.find_by_name(device_name)
    device.remove_descendants
    device.create_encryption("cr_device")
  end

  def encrypt_and_use_device(device_name)
    encryption = encrypt_device(device_name)
    vg = Y2Storage::LvmVg.create(system_graph, "vg0")
    vg.add_lvm_pv(encryption)
  end

  before do
    devicegraph_stub(scenario)

    allow(Y2Partitioner::DeviceGraphs.instance).to receive(:disk_analyzer)
      .and_return(disk_analyzer)

    subject.selected_fstab = selected_fstab
    subject.format_system_volumes = format_system_volumes
  end

  let(:disk_analyzer) do
    instance_double(Y2Storage::DiskAnalyzer, fstabs: fstabs, crypttabs: crypttabs)
  end

  let(:fstabs) { [fstab1, fstab2, fstab3] }

  let(:crypttabs) { [] }

  let(:fstab1) { instance_double(Y2Storage::Fstab) }
  let(:fstab2) { instance_double(Y2Storage::Fstab) }
  let(:fstab3) { instance_double(Y2Storage::Fstab) }

  let(:selected_fstab) { nil }

  let(:format_system_volumes) { true }

  let(:ext3) { Y2Storage::Filesystems::Type::EXT3 }

  let(:ext4) { Y2Storage::Filesystems::Type::EXT4 }

  let(:btrfs) { Y2Storage::Filesystems::Type::BTRFS }

  subject { described_class.new }

  let(:scenario) { "mixed_disks.yml" }

  describe "#fstabs" do
    it "returns the list of fstabs in the system" do
      expect(subject.fstabs).to eq(fstabs)
    end
  end

  describe "#select_prev_fstab" do
    context "when the selected fstab is the first one" do
      let(:selected_fstab) { fstab1 }

      it "does not change the selected fstab" do
        subject.select_prev_fstab
        expect(subject.selected_fstab).to eq(fstab1)
      end
    end

    context "when the selected fstab is not the first one" do
      let(:selected_fstab) { fstab3 }

      it "selects the previous fstab" do
        subject.select_prev_fstab
        expect(subject.selected_fstab).to eq(fstab2)
      end
    end
  end

  describe "#select_next_fstab" do
    context "when the selected fstab is the last one" do
      let(:selected_fstab) { fstab3 }

      it "does not change the selected fstab" do
        subject.select_next_fstab
        expect(subject.selected_fstab).to eq(fstab3)
      end
    end

    context "when the selected fstab is not the last one" do
      let(:selected_fstab) { fstab1 }

      it "selects the next fstab" do
        subject.select_next_fstab
        expect(subject.selected_fstab).to eq(fstab2)
      end
    end
  end

  describe "#selected_first_fstab?" do
    context "when the first fstab is selected" do
      let(:selected_fstab) { fstab1 }

      it "returns true" do
        expect(subject.selected_first_fstab?).to eq(true)
      end
    end

    context "when the first fstab is not selected" do
      let(:selected_fstab) { fstab2 }

      it "returns false" do
        expect(subject.selected_first_fstab?).to eq(false)
      end
    end
  end

  describe "#selected_last_fstab?" do
    context "when the last fstab is selected" do
      let(:selected_fstab) { fstab3 }

      it "returns true" do
        expect(subject.selected_last_fstab?).to eq(true)
      end
    end

    context "when the last fstab is not selected" do
      let(:selected_fstab) { fstab2 }

      it "returns false" do
        expect(subject.selected_last_fstab?).to eq(false)
      end
    end
  end

  describe "#selected_fstab_errors" do
    let(:selected_fstab) { fstab1 }

    before do
      allow(fstab1).to receive(:filesystem_entries).and_return(entries)
      allow(fstab1).to receive(:filesystem).and_return(filesystem)

      allow(crypttab).to receive(:entries).and_return(crypttab_entries)
      allow(crypttab).to receive(:filesystem).and_return(filesystem)

      encrypt_device("/dev/sda1")
    end

    let(:filesystem) { current_graph.filesystems.first }

    let(:entries) { [entry1, entry2] }

    let(:entry1) { fstab_entry(entry1_device, "/", entry1_fs, [], 0, 0) }
    let(:entry2) { fstab_entry(entry2_device, "/data", ext3, [], 0, 0) }

    let(:entry1_fs) { ext3 }

    let(:crypttabs) { [crypttab] }

    let(:crypttab) { instance_double(Y2Storage::Crypttab) }

    let(:crypttab_entries) do
      [
        crypttab_entry("luks1", "/dev/sda1", "", [])
      ]
    end

    shared_examples "not importable entries error" do
      it "contains a not importable entries error" do
        expect(subject.selected_fstab_errors).to_not be_empty
        expect(subject.selected_fstab_errors).to include(/cannot be imported/)
      end
    end

    context "when the device is unknown for some fstab entry" do
      let(:entry1_device) { "/dev/mapper/luks2" } # unknown
      let(:entry2_device) { "/dev/sdb1" }

      # Mock #find_by_any_name that is called by SimpleEtcFstabEntry#find_device
      before { allow(Y2Storage::BlkDevice).to receive(:find_by_any_name) }

      include_examples "not importable entries error"
    end

    context "when the device is known for all fstab entries" do
      let(:entry1_device) { "/dev/mapper/luks1" } # needs crypttab file to find it
      let(:entry2_device) { "/dev/sdb1" }

      context "and some fstab device is used by other device" do
        before do
          use_device(entry2_device)
        end

        include_examples "not importable entries error"
      end

      context "and some fstab encrypted device is not active" do
        before do
          allow_any_instance_of(Y2Storage::Encryption).to receive(:active?).and_return(false)
        end

        include_examples "not importable entries error"
      end

      context "and no fstab device is used by other device and all fstab encryptions are active" do
        context "and no fstab device needs to be formatted" do
          let(:format_system_volumes) { false }

          it "does not contain errors" do
            expect(subject.selected_fstab_errors).to be_empty
          end
        end

        context "and some fstab device needs to be formatted" do
          let(:format_system_volumes) { true }

          context "and the filesystem type is 'auto' for that fstab entry" do
            let(:entry1_fs) { Y2Storage::Filesystems::Type::AUTO }

            include_examples "not importable entries error"
          end

          context "and the filesystem type is unknown for that fstab entry" do
            let(:entry1_fs) { Y2Storage::Filesystems::Type::UNKNOWN }

            include_examples "not importable entries error"
          end

          context "and the filesystem type is not supported for that fstab entry" do
            let(:entry1_fs) { Y2Storage::Filesystems::Type::NTFS }

            include_examples "not importable entries error"
          end

          context "and the filesystem type is known and supported for that fstab entry" do
            let(:entry1_fs) { ext3 }

            it "does not contain errors" do
              expect(subject.selected_fstab_errors).to be_empty
            end
          end
        end
      end
    end
  end

  describe "#import_mount_points" do
    let(:selected_fstab) { Y2Storage::Fstab.new }

    before do
      allow(selected_fstab).to receive(:entries).and_return(entries)
    end

    let(:entries) do
      [
        fstab_entry(entry_device, entry_mount_point, entry_fs, entry_mount_options, 0, 0)
      ]
    end

    let(:entry_device) { "/dev/sda2" }

    let(:entry_mount_point) { "/" }

    let(:entry_fs) { ext3 }

    let(:entry_mount_options) { ["rw"] }

    def device(devicegraph)
      entry = entries.find { |e| !e.device(devicegraph).nil? }

      return nil unless entry

      entry.device(devicegraph)
    end

    shared_examples "import data" do
      it "imports mount point and mount options from the fstab entry" do
        subject.import_mount_points

        expect(device(current_graph).filesystem.mount_path).to eq(entry_mount_point)
        expect(device(current_graph).filesystem.mount_options).to eq(entry_mount_options)
      end

      context "when the device is mounted by kernel name" do
        let(:entry_device) { "/dev/sda2" }

        it "sets mount by kernel name" do
          subject.import_mount_points

          mount_by = device(current_graph).filesystem.mount_point.mount_by

          expect(mount_by.is?(:device)).to eq(true)
        end
      end

      context "when the device is mounted by id" do
        let(:scenario) { "encrypted_partition.xml" }

        let(:entry_device) { "/dev/disk/by-id/ata-VBOX_HARDDISK_VB777f5d67-56603f01-part1" }

        it "sets mount by id" do
          subject.import_mount_points

          mount_by = device(current_graph).filesystem.mount_point.mount_by

          expect(mount_by.is?(:id)).to eq(true)
        end
      end

      context "when the device is mounted by path" do
        let(:scenario) { "encrypted_partition.xml" }

        let(:entry_device) { "/dev/disk/by-path/pci-0000:00:1f.2-ata-1-part1" }

        it "sets mount by path" do
          subject.import_mount_points

          mount_by = device(current_graph).filesystem.mount_point.mount_by

          expect(mount_by.is?(:path)).to eq(true)
        end
      end

      context "when the device is mounted by LABEL" do
        let(:entry_device) { "LABEL=root" }

        it "sets mount by label" do
          sid = device(system_graph).sid

          subject.import_mount_points

          mount_by = current_graph.find_device(sid).filesystem.mount_point.mount_by

          expect(mount_by.is?(:label)).to eq(true)
        end
      end

      context "when the device is mounted by UUID" do
        let(:scenario) { "swaps.yml" }

        let(:entry_device) { "UUID=11111111-1111-1111-1111-11111111" }

        it "sets mount by uuid" do
          sid = device(system_graph).sid

          subject.import_mount_points

          mount_by = current_graph.find_device(sid).filesystem.mount_point.mount_by

          expect(mount_by.is?(:uuid)).to eq(true)
        end
      end
    end

    shared_examples "format device" do
      context "and the fstab device is already formatted" do
        it "does not format the device" do
          subject.import_mount_points

          expect(device(current_graph).filesystem.type).to_not eq(entry_device)
          expect(device(current_graph).filesystem).to eq(device(initial_graph).filesystem)
        end
      end

      context "and the fstab device is not formatted yet" do
        before do
          device(system_graph).delete_filesystem
        end

        it "formats the device with the filesystem type indicated in the fstab entry" do
          subject.import_mount_points
          expect(device(current_graph).filesystem.type).to eq(entry_fs)
        end
      end
    end

    it "discards all current changes" do
      allow(selected_fstab).to receive(:entries).and_return([])

      device(current_graph).filesystem.mount_path = "/foo"

      expect(current_graph).to_not eq(system_graph)
      subject.import_mount_points
      expect(current_graph).to eq(system_graph)
    end

    context "when a fstab entry contains a not active encryption device" do
      before do
        encryption = encrypt_device("/dev/sda2")
        encryption.create_filesystem(ext3)
        encryption.filesystem.mount_path = "/home"

        allow_any_instance_of(Y2Storage::Encryption).to receive(:active?).and_return(false)
      end

      let(:entry_device) { "/dev/mapper/cr_device" }

      it "does not import the mount point" do
        subject.import_mount_points

        expect(device(current_graph).filesystem.mount_path).to_not eq(entry_mount_point)
        expect(device(current_graph).filesystem.mount_options).to_not eq(entry_mount_options)
      end
    end

    context "when a fstab entry contains an used device (e.g. LVM PV)" do
      before do
        use_device(entry_device)
      end

      it "does not import the mount point" do
        subject.import_mount_points

        expect(device(current_graph).filesystem).to be_nil
      end
    end

    context "when a fstab entry contains a system mount point" do
      let(:entry_mount_point) { "/opt" }

      include_examples "import data"

      context "and the option for formatting system volumes was selected" do
        let(:format_system_volumes) { true }

        context "and the fstab device is already formatted" do
          it "formats the device with the filesystem type indicated in the fstab entry" do
            subject.import_mount_points

            expect(device(current_graph).filesystem.type).to eq(entry_fs)
          end

          it "preserves the filesytem label" do
            subject.import_mount_points

            expect(device(current_graph).filesystem.label).to eq("root")
          end
        end

        context "and the fstab device is not formatted yet" do
          before do
            device(system_graph).delete_filesystem
          end

          it "formats the device with the filesystem type indicated in the fstab entry" do
            subject.import_mount_points

            expect(device(current_graph).filesystem.type).to eq(entry_fs)
          end
        end
      end

      context "and the option for formatting system volumes was not selected" do
        let(:format_system_volumes) { false }

        include_examples "format device"
      end
    end

    context "when the fstab entry does not contain a system mount point" do
      let(:entry_mount_point) { "/home" }

      include_examples "import data"

      include_examples "format device"
    end

    context "when a second fstab is selected" do
      let(:fstabs) { [fstab1, fstab2] }

      let(:crypttabs) { [crypttab1, crypttab2] }

      before do
        allow(fstab1).to receive(:filesystem_entries).and_return(fstab1_entries)
        allow(fstab1).to receive(:filesystem).and_return(fstab1_filesystem)

        allow(fstab2).to receive(:filesystem_entries).and_return(fstab2_entries)
        allow(fstab2).to receive(:filesystem).and_return(fstab2_filesystem)

        allow(crypttab1).to receive(:entries).and_return(crypttab1_entries)
        allow(crypttab1).to receive(:filesystem).and_return(crypttab1_filesystem)

        allow(crypttab2).to receive(:entries).and_return(crypttab2_entries)
        allow(crypttab2).to receive(:filesystem).and_return(crypttab2_filesystem)

        encrypt_device("/dev/sda1")
      end

      let(:fstab1) { instance_double(Y2Storage::Fstab) }
      let(:fstab2) { instance_double(Y2Storage::Fstab) }
      let(:crypttab1) { instance_double(Y2Storage::Crypttab) }
      let(:crypttab2) { instance_double(Y2Storage::Crypttab) }

      let(:fstab1_filesystem) { system_graph.find_by_name("/dev/sdb2").filesystem }
      let(:fstab2_filesystem) { system_graph.find_by_name("/dev/sdb3").filesystem }

      let(:crypttab1_filesystem) { fstab1_filesystem }
      let(:crypttab2_filesystem) { fstab2_filesystem }

      let(:fstab1_entries) do
        [
          fstab_entry("/dev/mapper/luks1", "/", ext3, [], 0, 0)
        ]
      end

      let(:fstab2_entries) do
        [
          fstab_entry("/dev/mapper/luks2", "/home", ext3, [], 0, 0)
        ]
      end

      let(:crypttab1_entries) do
        [
          crypttab_entry("luks1", "/dev/sda1", "", [])
        ]
      end

      let(:crypttab2_entries) do
        [
          crypttab_entry("luks2", "/dev/sda1", "", [])
        ]
      end

      def sda1
        current_graph.find_by_name("/dev/sda1")
      end

      let(:selected_fstab) { fstab1 }

      it "uses the proper crypttab to import the mount points" do
        subject.import_mount_points
        # Uses crypttab1 to find the device (luks1) and import the mount point
        expect(sda1.filesystem.mount_path).to eq("/")

        # Changes the fstab
        subject.selected_fstab = fstab2

        subject.import_mount_points
        # Uses crypttab2 to find the device (luks2) and import the mount point
        expect(sda1.filesystem.mount_path).to eq("/home")
      end
    end

    context "when the fstab contains a NFS entry" do
      before do
        Y2Storage::Filesystems::Nfs.create(system_graph, "srv", "/home/a")
      end

      let(:entries) do
        [
          fstab_entry("srv:/home/a", "/home", "", ["rw"], 0, 0)
        ]
      end

      it "imports mount point and mount options for the NFS entry" do
        subject.import_mount_points

        nfs = Y2Storage::Filesystems::Nfs.find_by_server_and_path(current_graph, "srv", "/home/a")

        expect(nfs.mount_path).to eq("/home")
        expect(nfs.mount_options).to eq(["rw"])
      end
    end

    context "when the imported root is Btrfs" do
      using Y2Storage::Refinements::SizeCasts

      let(:entries) do
        [
          fstab_entry("/dev/sda2", "/home", ext3, ["rw"], 0, 0),
          fstab_entry("/dev/sdb2", "/", btrfs, ["defaults"], 1, 1),
          fstab_entry("/dev/sda1", "/var", ext4, ["defaults"], 0, 0)
        ]
      end

      let(:root_vol) do
        Y2Storage::VolumeSpecification.new(
          "btrfs_default_subvolume" => "@@",
          "snapshots_configurable"  => true,
          "snapshots"               => snapshots,
          "subvolumes"              => [
            "srv", { "path" => "var", "copy_on_write" => false }, "home", "tmp"
          ]
        )
      end
      let(:snapshots) { true }

      before do
        allow(Y2Storage::VolumeSpecification).to receive(:for).with("/").and_return root_vol
        allow(root_vol).to receive(:min_size_with_snapshots).and_return min_snapshots
      end
      let(:min_snapshots) { 20.GiB }

      let(:root_filesystem) { current_graph.find_by_name("/dev/sdb2").filesystem }
      let(:subvol_mount_points) { root_filesystem.btrfs_subvolumes.map(&:mount_path).compact }

      it "creates the default subvolumes" do
        subject.import_mount_points
        expect(subvol_mount_points).to contain_exactly("/srv", "/tmp")
        expect(root_filesystem.default_btrfs_subvolume.path).to eq "@@"
      end

      it "does not create shadowed subvolumes" do
        subject.import_mount_points
        expect(subvol_mount_points).to_not include("/home", "/var")
      end

      context "if snapshots must be enabled by default" do
        let(:snapshots) { true }

        context "and the device is big enough" do
          let(:min_snapshots) { 20.GiB }

          it "sets #configure_snapper to true" do
            subject.import_mount_points
            expect(root_filesystem.configure_snapper).to eq true
          end
        end

        context "but the device is too small" do
          let(:min_snapshots) { 80.GiB }

          it "sets #configure_snapper to false" do
            subject.import_mount_points
            expect(root_filesystem.configure_snapper).to eq false
          end
        end
      end

      context "if snapshots must be disabled by default" do
        let(:snapshots) { false }

        context "and the device is big enough" do
          it "sets #configure_snapper to false" do
            subject.import_mount_points
            expect(root_filesystem.configure_snapper).to eq false
          end
        end

        context "and the device is too small" do
          let(:root_dev) { "/dev/sdb1" }

          it "sets #configure_snapper to false" do
            subject.import_mount_points
            expect(root_filesystem.configure_snapper).to eq false
          end
        end
      end
    end
  end
end
