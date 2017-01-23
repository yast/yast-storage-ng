#!/usr/bin/env rspec
#
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

require_relative "spec_helper"
require "y2storage/used_storage_features"

describe Y2Storage::UsedStorageFeatures do
  context "Created empty (with a nil devicegraph)" do
    subject { described_class.new(nil) }

    it "has no features" do
      expect(subject.collect_features).to eq []
    end

    it "requires no packages" do
      expect(subject.feature_packages).to eq []
    end

    it "is able to calculate packages for an independent feature set" do
      expect(described_class.packages_for([:UF_XFS, :UF_NFS])).to contain_exactly("nfs-client", "xfsprogs")
    end

    it "knows libstorage features despite having no devicegraph" do
      features = subject.libstorage_features
      expect(features).to include(:UF_XFS, :UF_BTRFS, :UF_LVM)
      expect(features).not_to include(:UF_WRGLBRMPF)
    end

    it "returns a reasonable bitmask for an existing feature" do
      expect(subject.bitmask(:UF_LVM)).to be > 0
    end

    it "throws a NameError if asked for a bitmask for a nonexisting feature" do
      expect { subject.bitmask(:UF_WRGLBRMPF) }.to raise_error(NameError)
    end
  end

  context "Created with a mocked devicegraph" do
    let(:dg_features) { ::Storage::UF_BTRFS | ::Storage::UF_LVM }
    let(:devicegraph) { instance_double("::Storage::devicegraph", used_features: dg_features) }
    subject { described_class.new(devicegraph) }

    it "requires exactly the expected storage-related packages" do
      expect(subject.feature_packages).to contain_exactly("btrfsprogs", "e2fsprogs", "lvm2")
    end

    it "has exactly the expected storage features" do
      expect(subject.collect_features).to contain_exactly(:UF_BTRFS, :UF_LVM)
    end

    it "is able to calculate packages for an independent feature set" do
      expect(described_class.packages_for([:UF_XFS, :UF_NFS])).to contain_exactly("nfs-client", "xfsprogs")
    end
  end

  context "Created with a YAML devicegraph" do
    before { fake_scenario(scenario) }
    let(:scenario) { "mixed_disks" }
    subject { described_class.new(fake_devicegraph) }

    it "has exactly the expected storage features" do
      expect(subject.collect_features).to contain_exactly(:UF_BTRFS, :UF_EXT4, :UF_NTFS, :UF_XFS)
    end

    it "requires exactly the expected storage-related packages" do
      expect(subject.feature_packages).to contain_exactly("btrfsprogs", "e2fsprogs", "ntfs-3g", "ntfsprogs", "xfsprogs")
    end
  end
end
