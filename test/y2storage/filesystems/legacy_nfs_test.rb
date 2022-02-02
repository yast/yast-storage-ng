#!/usr/bin/env rspec

# Copyright (c) [2022] SUSE LLC
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
require "y2storage/filesystems/legacy_nfs"

describe Y2Storage::Filesystems::LegacyNfs do
  subject(:filesystem) { described_class.new }

  describe "#nfs_options" do
    before do
      subject.fstopt = fstopt
    end

    let(:fstopt) { nil }

    it "returns a NfsOptions object" do
      expect(subject.nfs_options).to be_a(Y2Storage::Filesystems::NfsOptions)
    end

    context "if there is no fstab options" do
      let(:fstopt) { nil }

      it "returns a NfsOptions with defaults options" do
        expect(subject.nfs_options.to_fstab).to eq("defaults")
      end
    end

    context "if there are fstab options" do
      let(:fstopt) { "rw,fsck" }

      it "returns a NfsOptions with the options" do
        expect(subject.nfs_options.options).to contain_exactly("rw", "fsck")
      end
    end
  end

  describe "#legacy_version?" do
    context "when the filesystem type is NFS4" do
      before do
        allow(subject).to receive(:fs_type).and_return(Y2Storage::Filesystems::Type::NFS4)
      end

      it "returns true" do
        expect(subject.legacy_version?).to eq(true)
      end
    end

    context "when the filesystem type is NFS" do
      before do
        allow(subject).to receive(:fs_type).and_return(Y2Storage::Filesystems::Type::NFS)
      end

      context "and it has legacy options" do
        before do
          subject.fstopt = "minorversion=1"
        end

        it "returns true" do
          expect(subject.legacy_version?).to eq(true)
        end
      end

      context "and it has no legacy options" do
        before do
          subject.fstopt = "rw"
        end

        it "returns false" do
          expect(subject.legacy_version?).to eq(false)
        end
      end
    end
  end

  describe "#version" do
    it "returns a NfsVersion object" do
      expect(subject.version).to be_a(Y2Storage::Filesystems::NfsVersion)
    end

    it "returns the version according to the fstab options" do
      subject.fstopt = "vers=4.1"

      expect(subject.version.value).to eq("4.1")
    end
  end
end
