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
require "storage"
require "y2storage"
require_relative "support/proposal_examples"
require_relative "support/proposal_context"

describe Y2Storage::Proposal do
  describe "#propose" do
    using Y2Storage::Refinements::TestDevicegraph
    using Y2Storage::Refinements::SizeCasts
    using Y2Storage::Refinements::DevicegraphLists

    include_context "proposal"

    context "in a PC with no partition table" do
      let(:scenario) { "empty_hard_disk_50GiB" }
      let(:expected_scenario) { "empty_hard_disk_gpt_50GiB" }
      include_examples "all proposed layouts"
    end

    context "in a windows-only PC with MBR partition table" do
      let(:scenario) { "windows-pc" }
      include_examples "all proposed layouts"
    end

    context "in a windows-only PC with 256 KiB of MBR gap" do
      let(:scenario) { "windows-pc-mbr256" }
      include_examples "LVM-based proposed layouts"
      include_examples "partition-based proposed layouts"
    end

    context "in a windows-only PC with 128 KiB of MBR gap" do
      let(:scenario) { "windows-pc-mbr128" }

      context "using LVM" do
        let(:lvm) { true }

        context "with a separate home" do
          let(:separate_home) { true }

          it "fails to make a proposal" do
            expect { proposal.propose }.to raise_error Y2Storage::Proposal::Error
          end
        end

        context "without separate home" do
          let(:separate_home) { false }

          it "fails to make a proposal" do
            expect { proposal.propose }.to raise_error Y2Storage::Proposal::Error
          end
        end
      end

      include_examples "partition-based proposed layouts"
    end

    context "in a windows/linux multiboot PC with MBR partition table" do
      let(:scenario) { "windows-linux-multiboot-pc" }
      include_examples "all proposed layouts"
    end

    context "in a linux multiboot PC with MBR partition table" do
      let(:scenario) { "multi-linux-pc" }
      let(:windows_partitions) { {} }
      include_examples "all proposed layouts"
    end

    context "in a windows/linux multiboot PC with pre-existing LVM and MBR partition table" do
      let(:scenario) { "windows-linux-lvm-pc" }
      include_examples "LVM-based proposed layouts"
      include_examples "partition-based proposed layouts"
    end

    context "in a windows-only PC with GPT partition table" do
      let(:scenario) { "windows-pc-gpt" }

      include_examples "all proposed layouts"
    end

    context "in a windows/linux multiboot PC with GPT partition table" do
      let(:scenario) { "windows-linux-multiboot-pc-gpt" }

      include_examples "all proposed layouts"
    end

    context "in a linux multiboot PC with GPT partition table" do
      let(:scenario) { "multi-linux-pc-gpt" }
      let(:windows_partitions) { {} }

      include_examples "all proposed layouts"
    end

    context "in a windows/linux multiboot PC with pre-existing LVM and GPT partition table" do
      let(:scenario) { "windows-linux-lvm-pc-gpt" }

      include_examples "LVM-based proposed layouts"
      include_examples "partition-based proposed layouts"
    end

    context "in a PC with an empty partition table" do
      let(:scenario) { "empty_hard_disk_mbr_50GiB" }

      include_examples "all proposed layouts"
    end

    context "in a PC with an empty GPT partition table" do
      let(:scenario) { "empty_hard_disk_gpt_50GiB" }

      include_examples "all proposed layouts"
    end

    context "when forced to create a small partition" do
      let(:scenario) { "empty_hard_disk_gpt_25GiB" }
      let(:windows_partitions) { {} }
      let(:separate_home) { true }
      let(:lvm) { false }

      it "does not fail to make a proposal" do
        expect { proposal.propose }.to_not raise_error
      end

      it "creates all the needed partitions" do
        proposal.propose
        expect(proposal.devices.partitions).to contain_exactly(
          an_object_with_fields(id: Storage::ID_BIOS_BOOT),
          an_object_with_fields(mountpoint: "/"),
          an_object_with_fields(mountpoint: "/home"),
          an_object_with_fields(mountpoint: "swap")
        )
      end
    end

    context "with pre-existing swap partitions" do
      before do
        allow(Y2Storage::Proposal::VolumesGenerator).to receive(:new).and_return volumes_generator
        settings.root_device = "/dev/sda"
      end

      let(:scenario) { "swaps" }
      let(:windows_partitions) { {} }
      let(:volumes_generator) do
        base_volumes = [
          planned_vol(mount_point: "/", type: :ext4, desired: 500.MiB, max: 500.MiB)
        ]
        all_volumes = [
          planned_vol(mount_point: "/", type: :ext4, desired: 500.MiB, max: 500.MiB),
          planned_vol(mount_point: "swap", reuse: "/dev/sda3"),
          planned_vol(mount_point: "swap", type: :swap, desired: 500.MiB, max: 500.MiB),
          planned_vol(mount_point: "swap", type: :swap, desired: 500.MiB, max: 500.MiB),
          planned_vol(mount_point: "swap", type: :swap, desired: 500.MiB, max: 500.MiB)
        ]
        instance_double(
          "Y2Storage::Proposal::VolumesGenerator",
          base_volumes: Y2Storage::PlannedVolumesList.new(base_volumes),
          all_volumes:  Y2Storage::PlannedVolumesList.new(all_volumes)
        )
      end

      it "reuses suitable swap partitions" do
        proposal.propose
        sda3 = proposal.devices.partitions.with(name: "/dev/sda3").first
        expect(sda3).to match_fields(
          mountpoint: "swap",
          uuid:       "33333333-3333-3333-3333-33333333",
          label:      "swap3",
          size:       (1.GiB - 1.MiB).to_i
        )
      end

      it "reuses UUID and label of deleted swap partitions" do
        proposal.propose
        sda2 = proposal.devices.partitions.with(name: "/dev/sda2").first
        expect(sda2).to match_fields(
          mountpoint: "swap",
          uuid:       "11111111-1111-1111-1111-11111111",
          label:      "swap1",
          size:       500.MiB.to_i
        )
        sda5 = proposal.devices.partitions.with(name: "/dev/sda5").first
        expect(sda5).to match_fields(
          mountpoint: "swap",
          uuid:       "22222222-2222-2222-2222-22222222",
          label:      "swap2",
          size:       500.MiB.to_i
        )
      end

      it "does not enforce any particular UUID or label for additional swaps" do
        proposal.propose
        sda6 = proposal.devices.partitions.with(name: "/dev/sda6").first
        expect(sda6).to match_fields(mountpoint: "swap", uuid: "", label: "")
      end
    end

    context "when installing on several GPT and MBR disks" do
      let(:scenario) { "gpt_and_msdos" }
      let(:separate_home) { true }
      let(:lvm) { false }
      let(:expected) do
        file_name = "#{scenario}-#{yaml_suffix}"
        ::Storage::Devicegraph.new_from_file(output_file_for(file_name))
      end

      before do
        settings.candidate_devices = ["/dev/sda", "/dev/sdb"]
        settings.root_device = root_device
      end

      context "if no disk is enforced for '/'" do
        let(:root_device) { nil }
        let(:yaml_suffix) { "sdb_root_device" }

        include_examples "proposed layout"

        it "allocates the root device in the biggest suitable disk" do
          proposal.propose
          fs = proposal.devices.filesystems
          expect(fs.with_mountpoint("/").disks.first.name).to eq "/dev/sdb"
        end
      end

      context "if a disk without free space is chosen for '/'" do
        let(:root_device) { "/dev/sda" }
        let(:yaml_suffix) { "sda_root_device" }

        include_examples "proposed layout"

        it "allocates in the root device the partitions that must be there" do
          proposal.propose
          fs = proposal.devices.filesystems
          expect(fs.with_mountpoint("/").disks.first.name).to eq "/dev/sda"
        end

        it "allocates other partitions in the already available space" do
          proposal.propose
          fs = proposal.devices.filesystems
          expect(fs.with_mountpoint("/home").disks.first.name).to eq "/dev/sdb"
          expect(fs.with_mountpoint("swap").disks.first.name).to eq "/dev/sdb"
        end
      end

      context "if a disk with enough free space is chosen for '/'" do
        let(:root_device) { "/dev/sdb" }
        let(:yaml_suffix) { "sdb_root_device" }

        include_examples "proposed layout"

        it "allocates all the partitions there" do
          proposal.propose
          filesystems = proposal.devices.filesystems.with_mountpoint(["/", "/home", "swap"])
          expect(filesystems.disks.map(&:name)).to eq ["/dev/sdb"]
        end
      end

      context "if '/' is placed in a GPT disk (legacy boot)" do
        let(:root_device) { "/dev/sdb" }

        it "creates a bios_boot partition if it's not there" do
          proposal.propose
          bios_boot = proposal.devices.partitions.with(id: Storage::ID_BIOS_BOOT)

          expect(bios_boot).to_not be_empty
        end
      end

      context "if '/' is placed in a MBR disk (legacy boot)" do
        let(:root_device) { "/dev/sda" }

        it "does not create a bios_boot partition" do
          proposal.propose
          bios_boot = proposal.devices.partitions.with(id: Storage::ID_BIOS_BOOT)

          expect(bios_boot).to be_empty
        end
      end
    end
  end
end
