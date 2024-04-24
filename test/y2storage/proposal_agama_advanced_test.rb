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
    let(:control_file_content) { { "partitioning" => { "proposal" => {}, "volumes" => volumes } } }
    let(:volumes) { [root_vol, swap_vol] }
    let(:root_vol) do
      { "mount_point" => "/", "fs_type" => "xfs", "min_size" => "30 GiB" }
    end
    let(:swap_vol) do
      { "mount_point" => "swap", "fs_type" => "swap", "min_size" => "1 GiB", "max_size" => "2 GiB" }
    end

    let(:scenario) { "mixed_disks" }

    before do
      # Speed-up things by avoiding calls to hwinfo
      allow_any_instance_of(Y2Storage::Disk).to receive(:hwinfo).and_return(Y2Storage::HWInfoDisk.new)

      # Remove existing mount points, this is a new installation
      fake_devicegraph.mount_points.each { |i| i.parents.first.remove_mount_point }

      settings.space_settings.strategy = :bigger_resize
      settings.lvm_vg_reuse = false
      # Agama uses homogeneous weights for all volumes
      settings.volumes.each { |v| v.weight = 100 }
      # Activate support for separate LVM VGs
      settings.separate_vgs = true
    end

    context "when there are resize actions for a disk that already contains the needed space" do
      let(:resize_info) do
        instance_double("Y2Storage::ResizeInfo", resize_ok?: true, reasons: 0, reason_texts: [],
          min_size: Y2Storage::DiskSize.GiB(40), max_size: Y2Storage::DiskSize.GiB(200))
      end

      let(:lvm) { true }

      before do
        settings.candidate_devices = ["/dev/sdb"]
        settings.root_device = "/dev/sda"
        settings.space_settings.actions = { "/dev/sda1" => :resize, "/dev/sda2" => :resize }
        allow(storage_arch).to receive(:efiboot?).and_return(true)
      end

      # This used to fail when evaluating the resize actions at sda1 and/or sda2, although
      # those actions are not really needed to allocate /boot/efi (the only partition that
      # needs to get created at sda).
      it "does not crash" do
        expect { proposal.propose }.to_not raise_error
      end
    end

    context "with one disk containing partitions and another directly formatted" do
      let(:scenario) { "gpt_msdos_and_empty" }

      let(:lvm) { true }

      before do
        settings.candidate_devices = ["/dev/sdc", "/dev/sdf"]
        settings.root_device = "/dev/sdc"
      end

      let(:volumes) { [{ "mount_point" => "/", "fs_type" => "xfs", "min_size" => size }] }

      context "if there is no need to use the formatted disk (everything fits in the other)" do
        let(:size) { "200 GiB" }

        it "does not modify the formatted disk" do
          proposal.propose
          disk = proposal.devices.find_by_name("/dev/sdf")
          expect(disk.filesystem.type.is?(:xfs)).to eq true
          expect(disk.partitions).to be_empty
        end
      end

      context "if the formatted disk needs to be used" do
        let(:size) { "970 GiB" }

        it "empties the disk deleting the filesystem" do
          proposal.propose
          disk = proposal.devices.find_by_name("/dev/sdf")
          expect(disk.filesystem).to be_nil
          expect(disk.partitions).to_not be_empty
        end
      end

      context "if non-mandatory actions are possible to make space" do
        let(:size) { "100 GiB" }

        before do
          settings.candidate_devices = ["/dev/sda", "/dev/sdf"]
          settings.root_device = "/dev/sda"
        end

        it "tries to use the formatted disk before trying an optional delete" do
          sda1_sid = fake_devicegraph.find_by_name("/dev/sda1").sid

          settings.space_settings.actions = { "/dev/sda1" => :delete }
          proposal.propose
          expect(proposal.failed?).to eq false

          disk = proposal.devices.find_by_name("/dev/sdf")
          expect(disk.filesystem).to be_nil
          expect(disk.partitions).to_not be_empty

          expect(proposal.devices.find_by_name("/dev/sda1").sid).to eq sda1_sid
        end

        it "tries to use the formatted disk before trying an optional resize" do
          orig_sda1 = fake_devicegraph.find_by_name("/dev/sda1")

          settings.space_settings.actions = { "/dev/sda1" => :resize }
          proposal.propose
          expect(proposal.failed?).to eq false

          disk = proposal.devices.find_by_name("/dev/sdf")
          expect(disk.filesystem).to be_nil
          expect(disk.partitions).to_not be_empty

          sda1 = proposal.devices.find_by_name("/dev/sda1")
          expect(sda1.sid).to eq orig_sda1.sid
          expect(sda1.size).to eq orig_sda1.size
        end
      end
    end
  end
end
