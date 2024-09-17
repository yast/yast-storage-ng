#!/usr/bin/env rspec
# Copyright (c) [2024] SUSE LLC
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
require_relative "#{TEST_PATH}/support/proposal_examples"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::MinGuidedProposal do
  describe "#propose with settings in the Agama style" do
    subject(:proposal) { described_class.new(settings: settings) }

    include_context "proposal"

    let(:architecture) { :x86 }
    let(:settings_format) { :ng }
    let(:separate_home) { true }
    let(:control_file_content) { { "partitioning" => { "volumes" => volumes } } }
    let(:space_actions) { [] }

    let(:scenario) { "lvm-two-vgs" }
    let(:resize_info) do
      instance_double("Y2Storage::ResizeInfo", resize_ok?: true, reasons: 0, reason_texts: [],
        min_size: Y2Storage::DiskSize.GiB(4), max_size: Y2Storage::DiskSize.TiB(2))
    end

    # Let's define some volumes to shuffle them around among the disks
    let(:volumes) { [root_vol, srv_vol, swap_vol] }
    let(:root_vol) do
      {
        "mount_point" => "/", "fs_type" => "btrfs", "min_size" => "5 GiB", "max_size" => "30 GiB",
        "snapshots" => true, "snapshots_percentage" => 160
      }
    end
    let(:srv_vol) do
      { "mount_point" => "/srv", "fs_type" => "xfs", "min_size" => "5 GiB", "max_size" => "10 GiB" }
    end
    let(:swap_vol) do
      { "mount_point" => "swap", "fs_type" => "swap", "min_size" => "2 GiB", "max_size" => "6 GiB" }
    end

    let(:delete) { Y2Storage::SpaceActions::Delete }
    let(:resize) { Y2Storage::SpaceActions::Resize }

    before do
      # Speed-up things by avoiding calls to hwinfo
      allow_any_instance_of(Y2Storage::Disk).to receive(:hwinfo).and_return(Y2Storage::HWInfoDisk.new)

      # Install into /dev/sda by default
      settings.candidate_devices = ["/dev/sda"]
      settings.root_device = "/dev/sda"

      # Agama uses homogeneous weights for all volumes and prevents swap reusing
      settings.volumes.each { |v| v.weight = 100 }
      settings.swap_reuse = :none
      # Activate support for separate LVM VGs
      settings.separate_vgs = true

      settings.space_settings.strategy = :bigger_resize
      settings.space_settings.actions = space_actions
    end

    context "when reusing an existing plain partition in the target disk" do
      before do
        srv = settings.volumes.find { |v| v.mount_point == "/srv" }
        srv.reuse_name = "/dev/sda8"
        srv.reformat = reformat
      end

      let(:space_actions) do
        [delete.new("/dev/sda1"), delete.new("/dev/sda2"), delete.new("/dev/sda8")]
      end
      let(:original_sda8) { fake_devicegraph.find_by_name("/dev/sda8") }

      context "keeping its filesystem" do
        let(:reformat) { false }

        it "does not delete the reused partition even if told to do so" do
          proposal.propose
          new_partition = proposal.devices.find_device(original_sda8.sid)
          expect(new_partition).to_not be_nil
        end

        it "does not format the reused partition" do
          proposal.propose
          filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/srv" }
          expect(filesystem.type.is?(:ext4)).to eq true
          expect(filesystem.blk_devices.first.sid).to eq original_sda8.sid
        end
      end

      context "not keeping its filesystem" do
        let(:reformat) { true }

        it "does not delete the reused partition even if told to do so" do
          proposal.propose
          new_partition = proposal.devices.find_device(original_sda8.sid)
          expect(new_partition).to_not be_nil
        end

        it "formats the reused partition" do
          proposal.propose
          filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/srv" }
          expect(filesystem.type.is?(:xfs)).to eq true
          expect(filesystem.blk_devices.first.sid).to eq original_sda8.sid
        end
      end
    end

    context "when reusing an existing encrypted partition in the target disk" do
      let(:scenario) { "gpt_encryption" }

      before do
        srv = settings.volumes.find { |v| v.mount_point == "/srv" }
        srv.reuse_name = "/dev/sda4"
        srv.reformat = reformat
      end

      let(:space_actions) { [delete.new("/dev/sda1"), delete.new("/dev/sda4")] }
      let(:original_sda4) { fake_devicegraph.find_by_name("/dev/sda4") }

      context "keeping its filesystem" do
        let(:reformat) { false }

        it "does not delete the reused partition even if told to do so" do
          proposal.propose
          new_partition = proposal.devices.find_device(original_sda4.sid)
          expect(new_partition).to_not be_nil
        end

        it "keeps the encryption layer on the reused partition and does not format it" do
          proposal.propose
          filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/srv" }
          expect(filesystem.type.is?(:btrfs)).to eq true
          blk_device = filesystem.blk_devices.first
          expect(blk_device.is?(:luks)).to eq true
          expect(blk_device.plain_device.sid).to eq original_sda4.sid
        end
      end

      context "not keeping its filesystem" do
        let(:reformat) { true }

        it "does not delete the reused partition even if told to do so" do
          proposal.propose
          new_partition = proposal.devices.find_device(original_sda4.sid)
          expect(new_partition).to_not be_nil
        end

        it "keeps the encryption layer on the reused partition and formats it" do
          proposal.propose
          filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/srv" }
          expect(filesystem.type.is?(:xfs)).to eq true
          blk_device = filesystem.blk_devices.first
          expect(blk_device.is?(:luks)).to eq true
          expect(blk_device.plain_device.sid).to eq original_sda4.sid
        end
      end
    end

    context "when reusing existing logical volumes" do
      before do
        srv = settings.volumes.find { |v| v.mount_point == "/srv" }
        srv.reuse_name = "/dev/vg1/lv1"
        srv.reformat = reformat
      end

      let(:space_actions) do
        [delete.new("/dev/sda1"), delete.new("/dev/sda2"), delete.new("/dev/sda5")]
      end
      let(:original_sda5) { fake_devicegraph.find_by_name("/dev/sda5") }

      context "keeping its filesystem" do
        let(:reformat) { false }

        it "does not delete the physical volumes of the reused volume group even if told to do so" do
          proposal.propose
          partition = proposal.devices.find_device(original_sda5.sid)
          expect(partition).to_not be_nil
        end

        it "uses the logical volume without formatting it" do
          proposal.propose
          filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/srv" }
          expect(filesystem.blk_devices.first.name).to eq "/dev/vg1/lv1"
          expect(filesystem.type.is?(:ext4)).to eq true
        end
      end

      context "not keeping its filesystem" do
        let(:reformat) { true }

        it "does not delete the physical volumes of the reused volume group even if told to do so" do
          proposal.propose
          partition = proposal.devices.find_device(original_sda5.sid)
          expect(partition).to_not be_nil
        end

        it "uses and formats the logical volume" do
          proposal.propose
          filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/srv" }
          expect(filesystem.blk_devices.first.name).to eq "/dev/vg1/lv1"
          expect(filesystem.type.is?(:xfs)).to eq true
        end
      end
    end

    context "when installing in a formatted disk" do
      let(:scenario) { "disks_and_md_raids" }

      before do
        settings.candidate_devices = ["/dev/sdc"]
        settings.root_device = "/dev/sdc"
      end

      # In the past, a delete action on the disk was requested. We later decided that actions
      # only make sense for partitions and LVs
      it "makes the expected proposal" do
        expect(proposal.propose).to eq true
        disk = proposal.devices.find_by_name(settings.root_device)
        expect(disk.partitions.size).to eq 4
      end
    end

    context "when directly formatting a disk" do
      let(:scenario) { "disks_and_md_raids" }

      context "if the disk was already formatted" do
        before do
          srv = settings.volumes.find { |v| v.mount_point == "/srv" }
          srv.reuse_name = "/dev/sdc"
        end

        # No space action needed for sdc, see above
        it "formats the disk and assigns the mount point" do
          proposal.propose
          filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/srv" }
          expect(filesystem.blk_devices.first.name).to eq "/dev/sdc"
          expect(filesystem.type.is?(:xfs)).to eq true
        end
      end

      context "if the disk was previously partitioned" do
        before do
          srv = settings.volumes.find { |v| v.mount_point == "/srv" }
          srv.reuse_name = "/dev/sdb"
        end

        # In the past, delete actions were requested for the partitions. We later decided
        # they were not necessary for disks being explicitly reused for a volume.
        it "deletes the disk partitions even if there are no space actions about them" do
          proposal.propose
          disk = proposal.devices.find_by_name("/dev/sdb")
          expect(disk.partitions).to be_empty
        end

        it "formats the disk and assigns the mount point" do
          proposal.propose
          filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/srv" }
          expect(filesystem.blk_devices.first.name).to eq "/dev/sdb"
          expect(filesystem.type.is?(:xfs)).to eq true
        end
      end

      context "if the relocated volume is the root Btrfs with snapshots" do
        before do
          srv = settings.volumes.find { |v| v.mount_point == "/" }
          srv.reuse_name = "/dev/sdc"
        end

        # The proposal used to throw an exception when adjusting the Btrfs-related sizes
        # if the target device was a disk (so no sizes could actually be adjusted)
        it "makes the proposal and assigns the mount point" do
          proposal.propose
          filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/" }
          expect(filesystem.blk_devices.first.name).to eq "/dev/sdc"
          expect(filesystem.type.is?(:btrfs)).to eq true
        end
      end
    end

    context "when using the existing filesystem from a disk" do
      let(:scenario) { "disks_and_md_raids" }

      before do
        srv = settings.volumes.find { |v| v.mount_point == "/srv" }
        srv.reuse_name = "/dev/sdc"
        srv.reformat = false
      end

      it "assigns the mount point without formatting the disk" do
        proposal.propose
        filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/srv" }
        expect(filesystem.blk_devices.first.name).to eq "/dev/sdc"
        expect(filesystem.type.is?(:btrfs)).to eq true
      end
    end

    context "when directly formatting a MD RAID" do
      let(:scenario) { "disks_and_md_raids" }

      context "if the RAID was already formatted" do
        before do
          srv = settings.volumes.find { |v| v.mount_point == "/srv" }
          srv.reuse_name = "/dev/md1"
        end

        let(:space_actions) { [delete.new("/dev/sda2"), delete.new("/dev/sdb2")] }

        let(:original_sda2) { fake_devicegraph.find_by_name("/dev/sda2") }
        let(:original_sdb2) { fake_devicegraph.find_by_name("/dev/sdb2") }
        let(:original_md1) { fake_devicegraph.find_by_name("/dev/md1") }

        it "does not delete the members of the RAID even if told to do so" do
          proposal.propose
          partition = proposal.devices.find_device(original_sda2.sid)
          expect(partition).to_not be_nil
          partition = proposal.devices.find_device(original_sdb2.sid)
          expect(partition).to_not be_nil
        end

        # No space action needed for md1
        it "formats the md and assigns the mount point" do
          proposal.propose
          filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/srv" }
          expect(filesystem.blk_devices.first.sid).to eq original_md1.sid
          expect(filesystem.type.is?(:xfs)).to eq true
        end
      end

      context "if the RAID was previously partitioned" do
        before do
          srv = settings.volumes.find { |v| v.mount_point == "/srv" }
          srv.reuse_name = "/dev/md0"
        end

        let(:space_actions) { [delete.new("/dev/sda1"), delete.new("/dev/sdb1")] }

        let(:original_sda1) { fake_devicegraph.find_by_name("/dev/sda1") }
        let(:original_sdb1) { fake_devicegraph.find_by_name("/dev/sdb1") }
        let(:original_md0) { fake_devicegraph.find_by_name("/dev/md0") }

        it "does not delete the members of the RAID even if told to do so" do
          proposal.propose
          partition = proposal.devices.find_device(original_sda1.sid)
          expect(partition).to_not be_nil
          partition = proposal.devices.find_device(original_sdb1.sid)
          expect(partition).to_not be_nil
        end

        # Delete actions are not necessary since the MD is being explicitly reused by a volume.
        it "deletes the MD partitions even if there are no space actions about them" do
          proposal.propose
          partition = proposal.devices.find_by_name("/dev/md0p1")
          expect(partition).to be_nil
        end

        it "formats the md and assigns the mount point" do
          proposal.propose
          filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/srv" }
          expect(filesystem.blk_devices.first.sid).to eq original_md0.sid
        end
      end
    end

    context "when using the existing filesystem from a MD RAID" do
      let(:scenario) { "disks_and_md_raids" }

      before do
        srv = settings.volumes.find { |v| v.mount_point == "/srv" }
        srv.reuse_name = "/dev/md0p1"
        srv.reformat = false
      end

      let(:space_actions) { [delete.new("/dev/sda2"), delete.new("/dev/sdb2")] }

      let(:original_sda2) { fake_devicegraph.find_by_name("/dev/sda2") }
      let(:original_sdb2) { fake_devicegraph.find_by_name("/dev/sdb2") }

      it "does not delete the members of the RAID even if told to do so" do
        proposal.propose
        partition = proposal.devices.find_device(original_sda2.sid)
        expect(partition).to_not be_nil
        partition = proposal.devices.find_device(original_sdb2.sid)
        expect(partition).to_not be_nil
      end

      it "assigns the mount point without formatting the MD" do
        proposal.propose
        filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/srv" }
        expect(filesystem.type.is?(:ext4)).to eq true
        expect(filesystem.label).to eq "md0p1_ext4"
      end
    end

    context "when reusing an existing partition in a MD RAID" do
      let(:scenario) { "disks_and_md_raids" }

      before do
        srv = settings.volumes.find { |v| v.mount_point == "/srv" }
        srv.reuse_name = "/dev/md0p1"
        srv.reformat = false
      end

      let(:space_actions) { [delete.new("/dev/sda2"), delete.new("/dev/sdb2")] }

      let(:original_sda2) { fake_devicegraph.find_by_name("/dev/sda2") }
      let(:original_sdb2) { fake_devicegraph.find_by_name("/dev/sdb2") }
      let(:original_md0p1) { fake_devicegraph.find_by_name("/dev/md0p1") }

      it "does not delete the members of the RAID even if told to do so" do
        proposal.propose
        partition = proposal.devices.find_device(original_sda2.sid)
        expect(partition).to_not be_nil
        partition = proposal.devices.find_device(original_sdb2.sid)
        expect(partition).to_not be_nil
      end

      it "uses the partition" do
        proposal.propose
        filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/srv" }
        expect(filesystem.blk_devices.first.sid).to eq original_md0p1.sid
      end
    end

    context "when reusing a XEN partition" do
      let(:scenario) { "xen-disks-and-partitions.xml" }

      before do
        settings.candidate_devices = ["/dev/xvdc"]
        settings.root_device = "/dev/xvdc"
        srv = settings.volumes.find { |v| v.mount_point == "/srv" }
        srv.reuse_name = "/dev/xvda2"
        srv.reformat = reformat
      end

      context "keeping its filesystem" do
        let(:reformat) { false }

        it "assigns the mount point without formatting the MD" do
          proposal.propose
          filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/srv" }
          expect(filesystem.uuid).to eq "7608bc33-8dfd-4ae0-8f38-e5923deb9631"
        end
      end

      context "not keeping its filesystem" do
        let(:reformat) { true }

        it "formats the XEN partition and assigns the mount point" do
          proposal.propose
          filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/srv" }
          expect(filesystem.blk_devices.first.name).to eq "/dev/xvda2"
          expect(filesystem.uuid).to be_empty
        end
      end
    end

    context "when reusing a bcache device" do
      let(:scenario) { "bcache2.xml" }

      before do
        srv = settings.volumes.find { |v| v.mount_point == "/srv" }
        srv.reuse_name = "/dev/bcache0"
        srv.reformat = reformat
      end

      let(:space_actions) do
        [
          delete.new("/dev/sda1"), delete.new("/dev/sda2"), delete.new("/dev/sda3"),
          delete.new("/dev/sdb1"), delete.new("/dev/sdb2")
        ]
      end

      let(:original_sdb1) { fake_devicegraph.find_by_name("/dev/sdb1") }
      let(:original_sdb2) { fake_devicegraph.find_by_name("/dev/sdb2") }
      let(:original_bcache0) { fake_devicegraph.find_by_name("/dev/bcache0") }

      context "keeping its filesystem" do
        let(:reformat) { false }

        it "does not delete the partitions underlying the bcache even if told to do so" do
          proposal.propose
          partition = proposal.devices.find_device(original_sdb1.sid)
          expect(partition).to_not be_nil
          partition = proposal.devices.find_device(original_sdb2.sid)
          expect(partition).to_not be_nil
        end

        it "assigns the mount point without formatting the bcache device" do
          proposal.propose
          filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/srv" }
          expect(filesystem.uuid).to eq "63edf5de-e0ed-4b2c-850b-7a8f2ebd6391"
        end
      end

      context "not keeping its filesystem" do
        let(:reformat) { true }

        it "does not delete the partitions underlying the bcache even if told to do so" do
          proposal.propose
          partition = proposal.devices.find_device(original_sdb1.sid)
          expect(partition).to_not be_nil
          partition = proposal.devices.find_device(original_sdb2.sid)
          expect(partition).to_not be_nil
        end

        it "formats the bcache device and assigns the mount point" do
          proposal.propose
          filesystem = proposal.devices.filesystems.find { |i| i.mount_path == "/srv" }
          expect(filesystem.blk_devices.first.sid).to eq original_bcache0.sid
          expect(filesystem.uuid).to be_empty
        end
      end
    end
  end
end
