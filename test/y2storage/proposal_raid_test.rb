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

require_relative "spec_helper"
require "y2storage"
require_relative "#{TEST_PATH}/support/proposal_examples"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::GuidedProposal do
  describe ".initial" do
    include_context "proposal"
    subject(:proposal) { described_class.initial }

    let(:storage_arch) { instance_double("::Storage::Arch") }

    before do
      allow(Y2Storage::StorageManager.instance).to receive(:arch).and_return(storage_arch)
      allow(storage_arch).to receive(:efiboot?).and_return efi
    end

    context "with an MD RAID which is big enough and completely empty" do
      let(:scenario) { "empty-md_raid" }
      let(:control_file) { "legacy_settings.xml" }

      # For SLE-15-SP1 this works as described in this test. Although assuming
      # the system can boot from EFI partitions located inside a software RAID
      # is controversial, Dell is happy with this behavior (their S130/S140/S150
      # controllers has indeed proven to be able to boot the resulting setup)
      # and nobody has complained.
      #
      # This test was added after detecting bug#1161331 in the beta versions of
      # SLE-15-SP2. Instead of producing the same result than SLE-15-SP1, this
      # scenario resulted in an infinite loop with the SpaceMaker trying to
      # delete sda1 over and over again.
      context "with EFI boot" do
        let(:efi) { true }

        it "creates a successful proposal" do
          expect(proposal.failed?).to eq false
        end

        it "creates no new partitions directly in the disks" do
          sda_parts = proposal.devices.find_by_name("/dev/sda").partitions
          sdb_parts = proposal.devices.find_by_name("/dev/sdb").partitions
          expect(sda_parts.size).to eq 1
          expect(sdb_parts.size).to eq 1

          # Extra check to verify that both partitions are still used only to hold
          # the MD RAID
          common_children = (sda_parts + sdb_parts).flat_map(&:children).uniq.map(&:name)
          expect(common_children).to eq ["/dev/md/VirtualDisk01"]
        end

        it "makes a proposal by partitioning the MD RAID" do
          root_fs = Y2Storage::MountPoint.find_by_path(proposal.devices, "/").first.filesystem
          root_dev = root_fs.blk_devices.first
          expect(root_dev.is?(:partition)).to eq true
          expect(root_dev.name).to start_with "/dev/md/VirtualDisk01"

          efi_fs = Y2Storage::MountPoint.find_by_path(proposal.devices, "/boot/efi").first.filesystem
          efi_dev = efi_fs.blk_devices.first
          expect(efi_dev.is?(:partition)).to eq true
          expect(efi_dev.name).to start_with "/dev/md/VirtualDisk01"
        end
      end

      context "with legacy boot" do
        let(:efi) { false }

        it "creates a successful proposal" do
          expect(proposal.failed?).to eq false
        end

        it "creates no new partitions in the MD RAID" do
          raid = proposal.devices.find_by_name("/dev/md/VirtualDisk01")
          expect(raid.partitions).to be_empty
        end
      end
    end

    # Regression test for bsc#11166258, in which the PReP partition was proposed
    # inside the software MD RAID because it was considered a candidate device
    context "in a PowerPC multipath system with an available empty MD RAID" do
      let(:scenario) { "bug_11166258.xml" }

      let(:efi) { false }
      before do
        expect(storage_arch).to receive(:s390?).and_return false
        expect(storage_arch).to receive(:ppc?).and_return true
      end

      it "creates a successful proposal" do
        expect(proposal.failed?).to eq false
      end

      it "does not propose to create PReP partitions inside the RAID" do
        prep_parts = proposal.devices.partitions.select { |part| part.id.is?(:prep) }
        devices = prep_parts.map(&:partitionable)
        expect(devices.select { |d| d.is?(:raid) }).to be_empty
      end
    end
  end
end
