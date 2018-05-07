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
  let(:scenario) { "mixed_disks" }

  before do
    fake_scenario(scenario)
  end

  describe "#windows_partitions" do
    context "in a PC" do
      before do
        allow(Yast::Arch).to receive(:x86_64).and_return true
        allow_any_instance_of(::Storage::BlkFilesystem).to receive(:detect_content_info)
          .and_return(content_info)
      end
      let(:content_info) { double("::Storage::ContentInfo", windows?: true) }

      it "returns an empty array for disks with no Windows" do
        expect(analyzer.windows_partitions("/dev/sdb").empty?).to eq(true)
      end

      it "returns an array of partitions for disks with some Windows" do
        expect(analyzer.windows_partitions("/dev/sda")).to be_a Array
        expect(analyzer.windows_partitions("/dev/sda").size).to eq 1
        expect(analyzer.windows_partitions("/dev/sda").first).to be_a Y2Storage::Partition
      end
    end

    context "in a non-PC system" do
      before do
        allow(Yast::Arch).to receive(:x86_64).and_return false
        allow(Yast::Arch).to receive(:i386).and_return false
      end

      it "returns an empty array" do
        expect(analyzer.windows_partitions.empty?).to eq(true)
      end
    end
  end

  describe "#installed_systems" do
    before do
      allow(Yast::Arch).to receive(:x86_64).and_return true
      allow_any_instance_of(::Storage::BlkFilesystem).to receive(:detect_content_info)
        .and_return(content_info)
      allow_any_instance_of(Y2Storage::ExistingFilesystem).to receive(:release_name)
        .and_return release_name
    end

    let(:content_info) { double("::Storage::ContentInfo", windows?: true) }

    let(:release_name) { "openSUSE" }

    context "when there is a disk with a Windows" do
      it "returns 'Windows' as installed system for the corresponding disk" do
        expect(analyzer.installed_systems("/dev/sda")).to include("Windows")
      end

      it "does not return 'Windows' for other disks" do
        expect(analyzer.installed_systems("/dev/sdb")).not_to include("Windows")
        expect(analyzer.installed_systems("/dev/sdc")).not_to include("Windows")
      end
    end

    context "when there is a Linux" do
      it "returns release name for the corresponding disks" do
        expect(analyzer.installed_systems("/dev/sda")).to include(release_name)
        expect(analyzer.installed_systems("/dev/sdb")).to include(release_name)
      end

      it "does not return release name for other disks" do
        expect(analyzer.installed_systems("/dev/sdc")).not_to include(release_name)
      end
    end

    context "when there are several installed systems in a disk" do
      it "returns all installed systems for that disk" do
        expect(analyzer.installed_systems("/dev/sda"))
          .to contain_exactly("Windows", release_name)
      end
    end

    context "when there are not installed systems in a disk" do
      it "does not return installed systems for that disk" do
        expect(analyzer.installed_systems("/dev/sdc")).to be_empty
      end
    end
  end

  describe "#fstabs" do
    before do
      allow_any_instance_of(Y2Storage::ExistingFilesystem).to receive(:fstab)
    end

    it "tries to read a fstab file for each suitable root filesystem" do
      expect(Y2Storage::ExistingFilesystem).to receive(:new).exactly(5).times.and_call_original

      analyzer.fstabs
    end
  end

  describe "#candidate_disks" do
    it "relies on Devicegraph#disk_devices" do
      expect(fake_devicegraph).to receive(:disk_devices).at_least(:once).and_call_original
      analyzer.candidate_disks
    end
  end
end
