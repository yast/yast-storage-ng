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

require_relative "spec_helper"
require "y2storage"

describe Y2Storage::ProposalSettings do
  # Convenience method to find a particular volume in a list
  def volume(path, volumes)
    volumes.find { |v| v.mount_point == path }
  end

  let(:control_file_content) do
    Yast::XML.XMLToYCPFile(File.join(DATA_PATH, "control_files/volumes_ng", control_file))
  end

  before do
    Yast::ProductFeatures.Import(control_file_content)
  end

  subject(:settings) { Y2Storage::ProposalSettings.new_for_current_product }

  context "In a CaaSP configuration with root and separate /var/lib/docker" do
    let(:control_file) { "control.CAASP.xml" }

    describe "#ng_format?" do
      it "returns true" do
        expect(settings.ng_format?).to eq true
      end
    end

    describe "#volumes" do
      it "contains two volume specifications" do
        expect(settings.volumes.size).to eq 2
        expect(settings.volumes).to all(be_a(Y2Storage::VolumeSpecification))
      end

      it "contains a root volume with Btrfs" do
        root_vol = volume("/", settings.volumes)
        expect(root_vol.fs_type).to eq Y2Storage::Filesystems::Type::BTRFS
        expect(root_vol.proposed).to eq true
      end

      it "enforces snapshots for the root volume" do
        root_vol = volume("/", settings.volumes)
        expect(root_vol.snapshots).to eq true
        expect(root_vol.snapshots_configurable).to eq false
      end

      it "does not have a home volume" do
        expect(volume("/home", settings.volumes)).to be nil
      end

      it "does not have a swap volume" do
        expect(volume("swap", settings.volumes)).to be nil
      end

      it "contains a /var/lib/docker volume with Btrfs" do
        docker_vol = volume("/var/lib/docker", settings.volumes)
        expect(docker_vol.fs_type).to eq Y2Storage::Filesystems::Type::BTRFS
      end
    end
  end

  context "In a standard SLE-like configuration with root, swap and separate /home" do
    let(:control_file) { "control.SLE-like.xml" }

    describe "#ng_format?" do
      it "returns true" do
        expect(settings.ng_format?).to eq true
      end
    end

    describe "#volumes" do
      it "contains three volume specifications" do
        expect(settings.volumes.size).to eq 3
        expect(settings.volumes).to all(be_a(Y2Storage::VolumeSpecification))
      end

      it "contains a root volume with Btrfs" do
        root_vol = volume("/", settings.volumes)
        expect(root_vol.fs_type).to eq Y2Storage::Filesystems::Type::BTRFS
        expect(root_vol.proposed).to eq true
      end

      it "the root volume recommends snapshots, but does not enforce them" do
        root_vol = volume("/", settings.volumes)
        expect(root_vol.snapshots).to eq true
        expect(root_vol.snapshots_configurable).to eq true
      end

      it "contains a home volume" do
        expect(volume("/home", settings.volumes)).to_not be nil
      end

      it "contains a valid swap volume" do
        swap_vol = volume("swap", settings.volumes)
        expect(swap_vol.fs_type).to eq Y2Storage::Filesystems::Type::SWAP
      end
    end
  end

  context "In an extended SLE-like configuration with an additional /data volume" do
    let(:control_file) { "control.SLE-with-data.xml" }

    describe "#ng_format?" do
      it "returns true" do
        expect(settings.ng_format?).to eq true
      end
    end

    describe "#volumes" do
      it "contains four volume specifications" do
        expect(settings.volumes.size).to eq 4
        expect(settings.volumes).to all(be_a(Y2Storage::VolumeSpecification))
      end

      it "contains a root volume with Btrfs" do
        root_vol = volume("/", settings.volumes)
        expect(root_vol.fs_type).to eq Y2Storage::Filesystems::Type::BTRFS
        expect(root_vol.proposed).to eq true
      end

      it "the root volume recommends snapshots, but does not enforce them" do
        root_vol = volume("/", settings.volumes)
        expect(root_vol.snapshots).to eq true
        expect(root_vol.snapshots_configurable).to eq true
      end

      it "contains a home volume" do
        expect(volume("/home", settings.volumes)).to_not be nil
      end

      it "contains a valid swap volume" do
        swap_vol = volume("swap", settings.volumes)
        expect(swap_vol.fs_type).to eq Y2Storage::Filesystems::Type::SWAP
      end

      it "contains a /data volume" do
        expect(volume("/data", settings.volumes)).to_not be nil
      end
    end
  end
end
