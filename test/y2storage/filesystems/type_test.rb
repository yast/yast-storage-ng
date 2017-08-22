#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

describe Y2Storage::Filesystems::Type do
  describe "#to_human_string" do
    it "returns the description of the type" do
      expect(Y2Storage::Filesystems::Type::HFSPLUS.to_human_string).to eq "MacHFS+"
    end

    it "returns the internal name (#to_s) for types with no description" do
      expect(Y2Storage::Filesystems::Type::TMPFS.to_human_string).to eq "tmpfs"
    end
  end

  describe "#supported_fstab_options" do
    it "returns Array of supported options" do
      Y2Storage::Filesystems::Type.constants.each do |const|
        type = Y2Storage::Filesystems::Type.const_get(const)
        next unless type.is_a?(Y2Storage::Filesystems::Type)
        expect(type.supported_fstab_options).to be_a(::Array)
      end
    end
  end

  describe "#default_partition_id" do
    it "returns PartitionId object that is suggested to use with filesystem" do
      Y2Storage::Filesystems::Type.constants.each do |const|
        type = Y2Storage::Filesystems::Type.const_get(const)
        next unless type.is_a?(Y2Storage::Filesystems::Type)
        expect(type.default_partition_id).to be_a(::Y2Storage::PartitionId)
      end
    end
  end

  describe "#legacy_root_filesystems" do
    let(:reiserfs) { Y2Storage::Filesystems::Type::REISERFS }

    it "returns an array of filesystems that were valid for '/' mountpoint" do
      expect(Y2Storage::Filesystems::Type.legacy_root_filesystems).to include(reiserfs)
    end
  end

  describe "#legacy_home_filesystems" do
    let(:reiserfs) { Y2Storage::Filesystems::Type::REISERFS }

    it "returns an array of filesystems that were valid for '/home' mountpoint" do
      expect(Y2Storage::Filesystems::Type.legacy_home_filesystems).to include(reiserfs)
    end
  end

  describe "#legacy_root?" do
    context "for a filesystem that is not legacy" do
      it "returns false" do
        Y2Storage::Filesystems::Type.root_filesystems.each do |filesystem|
          expect(filesystem.legacy_root?).to eq(false)
        end
      end
    end

    context "for a legacy filesystem that was valid for '/' mountpoint" do
      it "returns true" do
        Y2Storage::Filesystems::Type.legacy_root_filesystems.each do |filesystem|
          expect(filesystem.legacy_root?).to eq(true)
        end
      end
    end
  end

  describe "#legacy_home?" do
    context "for a filesystem that is not legacy" do
      it "returns false" do
        Y2Storage::Filesystems::Type.home_filesystems.each do |filesystem|
          expect(filesystem.legacy_home?).to eq(false)
        end
      end
    end

    context "for a legacy filesystem that was valid for '/home' mount point" do
      it "returns true" do
        Y2Storage::Filesystems::Type.legacy_home_filesystems.each do |filesystem|
          expect(filesystem.legacy_home?).to eq(true)
        end
      end
    end
  end
end
