#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

describe Y2Storage::DiskAnalyzer do
  using Y2Storage::Refinements::SizeCasts

  subject(:analyzer) { described_class.new(fake_devicegraph) }

  before do
    fake_scenario(scenario)
  end

  describe "#mbr_gap" do
    let(:scenario) { "gpt_and_msdos" }

    it "returns the gap for every disk" do
      expect(analyzer.mbr_gap.keys).to eq(
        ["/dev/sda", "/dev/sdb", "/dev/sdc", "/dev/sdd", "/dev/sde", "/dev/sdf"]
      )
    end

    it "returns nil for disks without partition table" do
      expect(analyzer.mbr_gap["/dev/sde"]).to be_nil
    end

    it "returns nil for GPT disks without partitions" do
      expect(analyzer.mbr_gap["/dev/sdd"]).to be_nil
    end

    it "returns nil for GPT disks with partitions" do
      expect(analyzer.mbr_gap["/dev/sdb"]).to be_nil
    end

    it "returns nil for MS-DOS disks without partitions" do
      expect(analyzer.mbr_gap["/dev/sdc"]).to be_nil
    end

    it "returns the gap for MS-DOS disks with partitions" do
      expect(analyzer.mbr_gap["/dev/sda"]).to eq 1.MiB
      expect(analyzer.mbr_gap["/dev/sdf"]).to eq Y2Storage::DiskSize.zero
    end
  end

  describe "#windows_partitions" do
    let(:scenario) { "mixed_disks" }

    context "in a PC" do
      before do
        allow(Yast::Arch).to receive(:x86_64).and_return true
        allow_any_instance_of(::Storage::BlkFilesystem).to receive(:detect_content_info)
          .and_return(content_info)
      end
      let(:content_info) { double("::Storage::ContentInfo", windows?: true) }

      it "includes in the result all existent disks" do
        expect(analyzer.windows_partitions.keys).to contain_exactly("/dev/sda", "/dev/sdb", "/dev/sdc")
      end

      it "returns an empty array for disks with no Windows" do
        expect(analyzer.windows_partitions["/dev/sdb"]).to eq []
      end

      it "returns an array of partitions for disks with some Windows" do
        expect(analyzer.windows_partitions["/dev/sda"]).to be_a Array
        expect(analyzer.windows_partitions["/dev/sda"].size).to eq 1
        expect(analyzer.windows_partitions["/dev/sda"].first).to be_a Y2Storage::Partition
      end
    end

    context "in a non-PC system" do
      before do
        allow(Yast::Arch).to receive(:x86_64).and_return false
        allow(Yast::Arch).to receive(:i386).and_return false
      end

      it "returns an empty hash" do
        expect(analyzer.windows_partitions).to eq({})
      end
    end
  end

  describe "#swap_partitions" do
    let(:scenario) { "mixed_disks" }

    it "includes in the result all existent disks" do
      expect(analyzer.swap_partitions.keys).to contain_exactly("/dev/sda", "/dev/sdb", "/dev/sdc")
    end

    it "returns an empty array for disks with no swap" do
      expect(analyzer.swap_partitions["/dev/sda"]).to eq []
    end

    it "returns an array of partitions for disks with some swap" do
      expect(analyzer.swap_partitions["/dev/sdb"]).to be_a Array
      expect(analyzer.swap_partitions["/dev/sdb"].size).to eq 1
      expect(analyzer.swap_partitions["/dev/sdb"].first).to be_a Y2Storage::Partition
    end
  end

  describe "#installed_systems" do
    let(:scenario) { "mixed_disks" } # only to initialize the subject

    before do
      allow(analyzer).to receive(:windows_partitions).and_return windows_partitions

      allow(analyzer).to receive(:filesystems) do |disk|
        case disk.name
        when sda.name then sda_filesystems
        when sdb.name then sdb_filesystems
        when sdc.name then sdc_filesystems
        end
      end

      allow_any_instance_of(Y2Storage::ExistingFilesystem).to receive(:release_name)
        .and_return release_name
    end

    let(:sda) { instance_double(Storage::Disk, name: "/dev/sda") }
    let(:sdb) { instance_double(Storage::Disk, name: "/dev/sdb") }
    let(:sdc) { instance_double(Storage::Disk, name: "/dev/sdc") }

    let(:windows_partitions) { {} }

    let(:sda_filesystems) { [] }
    let(:sdb_filesystems) { [] }
    let(:sdc_filesystems) { [] }

    let(:release_name) { nil }

    it "returns a hash with all disks" do
      installed_systems = analyzer.installed_systems
      expect(installed_systems).to be_a(Hash)
      expect(installed_systems.keys).to contain_exactly(*[sda, sdb, sdc].map(&:name))
    end

    context "when there is a Windows" do
      let(:windows) { instance_double(Storage::Partition) }
      let(:windows_partitions) { { sda.name => [windows] } }

      it "returns 'Windows' as installed systems in the corresponding disk" do
        installed_systems = analyzer.installed_systems
        expect(installed_systems[sda.name]).to include("Windows")
      end

      it "does not return 'Windows' for other disks" do
        installed_systems = analyzer.installed_systems
        expect(installed_systems[sdb.name]).not_to include("Windows")
        expect(installed_systems[sdc.name]).not_to include("Windows")
      end
    end

    context "when there is a Linux" do
      let(:sdb_filesystems) { [instance_double(Storage::BlkFilesystem)] }
      let(:release_name) { "openSUSE" }

      it "returns release name for the corresponding disk" do
        installed_systems = analyzer.installed_systems
        expect(installed_systems[sdb.name]).to include(release_name)
      end

      it "does not return release name for other disks" do
        installed_systems = analyzer.installed_systems
        expect(installed_systems[sda.name]).not_to include(release_name)
        expect(installed_systems[sdc.name]).not_to include(release_name)
      end
    end

    context "when there are several installed systems in a disk" do
      let(:windows) { instance_double(Storage::Partition) }
      let(:windows_partitions) { { sdc.name => [windows] } }
      let(:sdc_filesystems) { [instance_double(Storage::BlkFilesystem)] }
      let(:release_name) { "openSUSE" }

      it "returns all installed systems for that disk" do
        installed_systems = analyzer.installed_systems
        expect(installed_systems[sdc.name]).to contain_exactly("Windows", release_name)
      end
    end
  end
end
