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
require "storage"
require "y2storage"
require_relative "support/proposal_examples"
require_relative "support/proposal_context"

describe Y2Storage::Proposal do
  describe "#propose subvolumes" do
    include_context "proposal"

    let(:subvol) { true }

    let(:proposal_devicegraph_yaml) do
      proposal.propose
      yaml_writer = Y2Storage::YamlWriter.new
      yaml_writer.yaml_device_tree(proposal.devices.to_storage_value)
    end

    let(:root_yaml) do
      disk = proposal_devicegraph_yaml.first["disk"]
      partitions = disk["partitions"]
      partitions.map do |pslot|
        part = pslot["partition"]
        next nil unless part
        part["mount_point"] == "/" ? part : nil
      end.compact.first
    end

    let(:subvol_yaml) do
      root = root_yaml || {}
      btrfs_yaml = root["btrfs"] || {}
      btrfs_yaml["subvolumes"] || []
    end

    # rubocop:disable Metrics/LineLength
    context "without separate /home on x86" do
      let(:architecture) { :x86 }
      let(:separate_home) { false }
      let(:scenario) { "empty_hard_disk_50GiB" }
      subject(:proposal) { described_class.new(settings: settings) }

      it "proposes normal (COW) subvolumes" do
        expect(subvol_yaml).to include("subvolume" => { "path" => "@/home" })
        expect(subvol_yaml).to include("subvolume" => { "path" => "@/opt" })
        expect(subvol_yaml).to include("subvolume" => { "path" => "@/srv" })
        expect(subvol_yaml).to include("subvolume" => { "path" => "@/usr/local" })
        expect(subvol_yaml).to include("subvolume" => { "path" => "@/var/log" })
      end

      it "proposes NoCOW subvolumes" do
        expect(subvol_yaml).to include("subvolume" => { "path" => "@/var/lib/libvirt/images", "nocow" => "true" })
        expect(subvol_yaml).to include("subvolume" => { "path" => "@/var/lib/mariadb", "nocow" => "true" })
        expect(subvol_yaml).to include("subvolume" => { "path" => "@/var/lib/mysql", "nocow" => "true" })
      end

      it "proposes the correct architecture specific subvolumes" do
        expect(subvol_yaml).to include("subvolume" => { "path" => "@/boot/grub2/i386-pc" })
        expect(subvol_yaml).to include("subvolume" => { "path" => "@/boot/grub2/x86_64-efi" })
        expect(subvol_yaml).not_to include("subvolume" => { "path" => "@/boot/grub2/s390x-emu" })
      end
    end

    context "with separate /home" do
      let(:architecture) { :x86 }
      let(:separate_home) { true }
      let(:scenario) { "empty_hard_disk_50GiB" }
      subject(:proposal) { described_class.new(settings: settings) }

      it "does not shadow /home with a subvolume" do
        expect(subvol_yaml).not_to include("subvolume" => { "path" => "@/home" })
      end

      it "proposes normal (COW) subvolumes" do
        expect(subvol_yaml).to include("subvolume" => { "path" => "@/opt" })
        expect(subvol_yaml).to include("subvolume" => { "path" => "@/srv" })
        expect(subvol_yaml).to include("subvolume" => { "path" => "@/usr/local" })
        expect(subvol_yaml).to include("subvolume" => { "path" => "@/var/log" })
      end
    end

    context "on s390" do
      let(:architecture) { :s390 }
      let(:separate_home) { false }
      let(:scenario) { "empty_hard_disk_50GiB" }
      subject(:proposal) { described_class.new(settings: settings) }

      it "proposes the correct architecture specific subvolumes for s390" do
        expect(subvol_yaml).to include("subvolume" => { "path" => "@/boot/grub2/s390x-emu" })
      end

      it "does not propose subvolumes for x86" do
        expect(subvol_yaml).not_to include("subvolume" => { "path" => "@/boot/grub2/i386-pc" })
        expect(subvol_yaml).not_to include("subvolume" => { "path" => "@/boot/grub2/x86_64-efi" })
      end
    end
    # rubocop:enable all
  end
end
