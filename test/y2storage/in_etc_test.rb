#!/usr/bin/env rspec
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

require_relative "spec_helper"
require "y2storage"

describe Y2Storage::BlkDevice do
  before { fake_scenario("empty_disks") }

  describe "#encrypt" do
    let(:disk) { fake_devicegraph.find_by_name("/dev/sda1") }

    context "when a new encrypted volume is created" do
      it "sets in_etc_crypttab to false" do
        disk.encrypt
        disk.encryption.create_filesystem(Y2Storage::Filesystems::Type::BTRFS)

        expect(disk.encryption.in_etc_crypttab?).to eq false
      end
    end
  end
end

describe Y2Storage::Device do
  before { fake_scenario("empty_disks") }

  describe "#update_etc_status" do
    let(:disk) { fake_devicegraph.find_by_name("/dev/sda1") }

    context "in a new encrypted volume" do
      context "when a mount point is created" do
        before do
          disk.encrypt
          disk.encryption.create_filesystem(Y2Storage::Filesystems::Type::BTRFS)
        end

        it "sets in_etc_crypttab to true" do
          disk.encryption.filesystem.create_mount_point("/foo")

          expect(disk.encryption.in_etc_crypttab?).to eq true
        end
      end

      context "when this mount point is removed again" do
        before do
          disk.encrypt
          disk.encryption.create_filesystem(Y2Storage::Filesystems::Type::BTRFS)
          disk.encryption.filesystem.create_mount_point("/foo")
        end

        it "sets in_etc_crypttab to false" do
          disk.encryption.filesystem.remove_mount_point

          expect(disk.encryption.in_etc_crypttab?).to eq false
        end
      end
    end

    describe "in a setup with an existing encrypted volume" do
      before { fake_scenario("encrypted_partition.xml") }

      let(:disk) { fake_devicegraph.find_by_name("/dev/sda1") }

      context "when there is initially no mount point" do
        it "sets in_etc_crypttab to false" do
          expect(disk.encryption.in_etc_crypttab?).to eq false
        end
      end

      context "when a mount point is created" do
        it "sets in_etc_crypttab to true" do
          disk.encryption.filesystem.create_mount_point("/foo")

          expect(disk.encryption.in_etc_crypttab?).to eq true
        end
      end

      context "when a mount point is removed" do
        context "if the /etc flags were automatically set by the mount point creation" do
          before do
            disk.encryption.filesystem.create_mount_point("/foo")
          end

          it "restores the false values for in_etc_crypttab" do
            disk.encryption.filesystem.remove_mount_point

            expect(disk.encryption.in_etc_crypttab?).to eq false
          end
        end

        context "if the /etc flags were already true before creating the mount point" do
          before do
            disk.encryption.to_storage_value.in_etc_crypttab = true
            disk.encryption.filesystem.create_mount_point("/foo")
          end

          it "keeps the original true values for in_etc_crypttab and in_etc_mdadm" do
            disk.encryption.filesystem.remove_mount_point

            expect(disk.encryption.in_etc_crypttab?).to eq true
          end
        end
      end
    end

    describe "in a setup with a RAID on top of an encrypted volume" do
      before { fake_scenario("subvolumes-and-empty-md.xml") }

      let(:md) { fake_devicegraph.find_by_name("/dev/md/strip0") }
      let(:encryption) { fake_devicegraph.find_by_name("/dev/mapper/cr_sda5") }

      # create a filesystem and mount point in the RAID
      def create_raid_mount_point
        fs = md.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
        fs.create_mount_point("/foo")
      end

      context "when there is initially no mount point for the RAID" do
        it "sets in_etc_crypttab and in_etc_mdadm to false in the underlying devices" do
          expect(md.in_etc_mdadm?).to eq false
          expect(encryption.in_etc_crypttab?).to eq false
        end
      end

      context "when a new mount point is created for the RAID" do
        it "sets in_etc_crypttab and in_etc_mdadm to true in the underlying devices" do
          expect(md.in_etc_mdadm?).to eq false
          expect(encryption.in_etc_crypttab?).to eq false

          create_raid_mount_point

          expect(md.in_etc_mdadm?).to eq true
          expect(encryption.in_etc_crypttab?).to eq true
        end
      end

      context "when a mount point is removed" do
        context "if the /etc flags were automatically set by the mount point creation" do
          before { create_raid_mount_point }

          it "restores the false values for in_etc_crypttab and in_etc_mdadm" do
            expect(md.in_etc_mdadm?).to eq true
            expect(encryption.in_etc_crypttab?).to eq true

            md.filesystem.remove_mount_point

            expect(md.in_etc_mdadm?).to eq false
            expect(encryption.in_etc_crypttab?).to eq false
          end
        end

        context "if the /etc flags were already true before creating the mount point" do
          before do
            md.to_storage_value.in_etc_mdadm = true
            encryption.to_storage_value.in_etc_crypttab = true
            create_raid_mount_point
          end

          it "keeps the original true values for in_etc_crypttab and in_etc_mdadm" do
            expect(md.in_etc_mdadm?).to eq true
            expect(encryption.in_etc_crypttab?).to eq true

            md.filesystem.remove_mount_point

            expect(md.in_etc_mdadm?).to eq true
            expect(encryption.in_etc_crypttab?).to eq true
          end
        end
      end
    end
  end
end
