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

require_relative "spec_helper"
require "y2storage"

describe Y2Storage::Device do
  before { fake_scenario("subvolumes-and-empty-md.xml") }

  describe "#update_etc_status" do
    let(:md) { fake_devicegraph.find_by_name("/dev/md/strip0") }
    let(:encryption) { fake_devicegraph.find_by_name("/dev/mapper/cr_sda5") }

    # Creates a filesystem and mount point in the RAID
    def create_mount_point
      fs = md.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
      fs.create_mount_point("/mnt")
    end

    context "when a new mount point is created" do
      it "sets in_etc_crypttab and in_etc_mdadm to true in the underlying devices" do
        expect(md.in_etc_mdadm?).to eq false
        expect(encryption.in_etc_crypttab?).to eq false

        create_mount_point

        expect(md.in_etc_mdadm?).to eq true
        expect(encryption.in_etc_crypttab?).to eq true
      end
    end

    context "when a mount point is removed" do
      context "if the /etc flags were automatically set by the mount point creation" do
        before { create_mount_point }

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
          create_mount_point
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
