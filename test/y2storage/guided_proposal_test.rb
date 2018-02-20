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
require_relative "#{TEST_PATH}/support/proposal_examples"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::GuidedProposal do
  using Y2Storage::Refinements::SizeCasts
  let(:architecture) { :x86 }

  include_context "proposal"

  let(:scenario) { "empty_hard_disk_gpt_25GiB" }

  describe ".initial" do
    subject(:proposal) { described_class.initial(settings: settings) }

    it "generates a proposal" do
      expect(proposal).to be_a(Y2Storage::GuidedProposal)
    end

    context "when settings are not passed" do
      let(:current_settings) { nil }

      before do
        allow(Y2Storage::ProposalSettings).to receive(:new_for_current_product)
          .and_call_original
      end

      it "creates initial proposal settings based on the product (control.xml)" do
        expect(Y2Storage::ProposalSettings).to receive(:new_for_current_product)
          .and_call_original
        proposal
      end
    end

    context "when settings has legacy format" do
      let(:settings_format) { :legacy }

      it "uses Legacy strategy to generate the initial proposal" do
        expect(Y2Storage::Proposal::InitialStrategies::Legacy).to receive(:new).and_call_original
        proposal
      end
    end

    context "when settings has ng format" do
      let(:settings_format) { :ng }

      let(:control_file_content) do
        {
          "partitioning" => {
            "proposal" => {
              "lvm" => false
            },
            "volumes"  => []
          }
        }
      end

      it "uses Ng strategy to generate the initial proposal" do
        expect(Y2Storage::Proposal::InitialStrategies::Ng).to receive(:new).and_call_original
        proposal
      end
    end

    # Regression test for bsc#1067349
    context "with a BIOS MD RAID" do
      let(:scenario) { "rste_swraid.xml" }

      it "does not rise an exception" do
        expect { described_class.initial(settings: settings) }.to_not raise_error
      end

      it "generates a valid calculated proposal" do
        result = described_class.initial(settings: settings)
        expect(result).to be_a Y2Storage::GuidedProposal
        expect(result.devices).to be_a Y2Storage::Devicegraph
      end
    end

    # Regression test for bsc#1071798
    context "with only an unformatted ECKD DASD" do
      let(:scenario) { "unformatted-eckd-dasd" }

      it "does not rise an exception" do
        expect { described_class.initial(settings: settings) }.to_not raise_error
      end

      it "generates a failed proposal" do
        result = described_class.initial(settings: settings)
        expect(result).to be_a Y2Storage::GuidedProposal
        expect(result.failed?).to eq true
      end
    end
  end

  describe "#propose" do
    subject(:proposal) { described_class.new(settings: settings) }

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
          an_object_having_attributes(id: Y2Storage::PartitionId::BIOS_BOOT),
          an_object_having_attributes(filesystem_mountpoint: "/"),
          an_object_having_attributes(filesystem_mountpoint: "/home"),
          an_object_having_attributes(filesystem_mountpoint: "swap")
        )
      end
    end

    context "when installing in a multipath device" do
      let(:scenario) { "empty-dasd-and-multipath.xml" }
      let(:windows_partitions) { {} }
      let(:separate_home) { true }
      let(:lvm) { false }

      before do
        # Focus on multipath devices
        settings.candidate_devices = fake_devicegraph.multipaths.map(&:name)
      end

      it "does not fail to make a proposal" do
        expect { proposal.propose }.to_not raise_error
      end

      it "creates the needed partitions in the multipath device" do
        proposal.propose

        multipath0, multipath1 = proposal.devices.multipaths
        expect(multipath0.partitions).to contain_exactly(
          an_object_having_attributes(filesystem_mountpoint: "/"),
          an_object_having_attributes(filesystem_mountpoint: "/home")
        )
        expect(multipath1.partitions).to contain_exactly(
          an_object_having_attributes(filesystem_mountpoint: "swap"),
          an_object_having_attributes(id: Y2Storage::PartitionId::BIOS_BOOT)
        )
      end

      it "creates the needed partitions with correct device names" do
        proposal.propose
        multipath0, multipath1 = proposal.devices.multipaths
        expect(multipath0.partitions.map(&:name)).to contain_exactly(
          "#{multipath0.name}-part1",
          "#{multipath0.name}-part2"
        )

        expect(multipath1.partitions.map(&:name)).to contain_exactly(
          "#{multipath1.name}-part1",
          "#{multipath1.name}-part2"
        )
      end
    end

    context "when installing in a DM RAID" do
      let(:scenario) { "empty-dm_raids_no_sda.xml" }
      let(:windows_partitions) { {} }
      let(:separate_home) { false }
      let(:lvm) { false }

      it "does not fail to make a proposal" do
        expect { proposal.propose }.to_not raise_error
      end

      it "creates the needed partitions in the DM RAID" do
        proposal.propose
        raids = proposal.devices.dm_raids.map(&:partitions).flatten
        expect(raids).to contain_exactly(
          an_object_having_attributes(id: Y2Storage::PartitionId::BIOS_BOOT),
          an_object_having_attributes(filesystem_mountpoint: "/"),
          an_object_having_attributes(filesystem_mountpoint: "swap")
        )
      end

      it "creates the needed partitions with correct device names" do
        proposal.propose
        # note: potentially order dependent; there are two raids defined
        raid0, raid1 = proposal.devices.dm_raids
        expect(raid0.partitions.map(&:name)).to contain_exactly(
          "#{raid0.name}-part1",
          "#{raid0.name}-part2"
        )
        expect(raid1.partitions.map(&:name)).to contain_exactly(
          "#{raid1.name}-part1"
        )
      end
    end

    context "when asked to delete all the existing partitions" do
      let(:scenario) { "windows-linux-lvm-pc" }
      let(:separate_home) { false }
      let(:lvm) { false }

      before do
        settings.windows_delete_mode = :all
        settings.linux_delete_mode = :all
        settings.other_delete_mode = :all
      end

      it "cleanups the disks before creating partitions" do
        proposal.propose
        expect(proposal.devices.partitions).to contain_exactly(
          an_object_having_attributes(filesystem_mountpoint: "/"),
          an_object_having_attributes(filesystem_mountpoint: "swap")
        )
      end
    end

    context "with pre-existing swap partitions" do
      before do
        allow(Y2Storage::Proposal::DevicesPlanner).to receive(:new).and_return dev_generator
        settings.root_device = "/dev/sda"
      end

      let(:scenario) { "swaps" }
      let(:windows_partitions) { {} }
      let(:all_volumes) do
        [
          planned_vol(mount_point: "/", type: :ext4, min: 500.MiB, max: 500.MiB),
          planned_vol(mount_point: "swap", reuse: "/dev/sda3"),
          planned_vol(mount_point: "swap", type: :swap, min: 500.MiB, max: 500.MiB),
          planned_vol(mount_point: "swap", type: :swap, min: 500.MiB, max: 500.MiB),
          planned_vol(mount_point: "swap", type: :swap, min: 500.MiB, max: 500.MiB)
        ]
      end
      let(:dev_generator) do
        instance_double("Y2Storage::Proposal::DevicesPlanner", planned_devices: all_volumes)
      end

      def sda(num)
        proposal.devices.find_by_name("/dev/sda#{num}")
      end

      it "reuses suitable swap partitions" do
        proposal.propose
        expect(sda(3)).to have_attributes(
          filesystem_mountpoint: "swap",
          filesystem_uuid:       "33333333-3333-3333-3333-33333333",
          filesystem_label:      "swap3",
          size:                  1.GiB - 1.MiB
        )
      end

      it "reuses UUID and label of deleted swap partitions" do
        proposal.propose
        expect(sda(2)).to have_attributes(
          filesystem_mountpoint: "swap",
          filesystem_uuid:       "11111111-1111-1111-1111-11111111",
          filesystem_label:      "swap1",
          size:                  500.MiB
        )
        expect(sda(5)).to have_attributes(
          filesystem_mountpoint: "swap",
          filesystem_uuid:       "22222222-2222-2222-2222-22222222",
          filesystem_label:      "swap2",
          size:                  500.MiB
        )
      end

      it "does not enforce any particular UUID or label for additional swaps" do
        proposal.propose
        expect(sda(6)).to have_attributes(
          filesystem_mountpoint: "swap", filesystem_uuid: "", filesystem_label: ""
        )
      end

      context "when it deletes partitions with id swap but not containing a swap" do
        let(:scenario) { "false-swaps" }
        let(:all_volumes) do
          [
            planned_vol(mount_point: "/", type: :ext4, min: 8.5.GiB),
            planned_vol(mount_point: "swap", type: :swap, min: 1.GiB)
          ]
        end

        # Regression test for bsc#1071515. It used to raise an exception when an
        # unformatted swap (like /dev/sda1 in our test data) had been deleted.
        it "does not fail" do
          expect { proposal.propose }.to_not raise_error
        end

        it "ignores UUIDs and labels of non-swap filesystems" do
          proposal.propose
          swap = proposal.devices.disks.first.swap_partitions.first
          expect(swap.filesystem.uuid).to_not eq "33333333-3333-3333-3333-33333333"
          expect(swap.filesystem.label).to_not eq "old_root"
        end

        it "reuses UUID and label of deleted real swap partitions" do
          proposal.propose
          swap = proposal.devices.disks.first.swap_partitions.first
          expect(swap.filesystem.uuid).to eq "44444444-4444-4444-4444-44444444"
          expect(swap.filesystem.label).to eq "old_swap"
        end
      end
    end

    context "when installing on several GPT and MBR disks" do
      let(:scenario) { "gpt_and_msdos" }
      let(:separate_home) { true }
      let(:lvm) { false }
      let(:expected) do
        file_name = "#{scenario}-#{yaml_suffix}"
        Y2Storage::Devicegraph.new_from_file(output_file_for(file_name))
      end

      before do
        settings.candidate_devices = ["/dev/sda", "/dev/sdb"]
        settings.root_device = root_device
      end

      def disk_for(mountpoint)
        proposal.devices.disks.detect do |disk|
          disk.partitions.any? { |p| p.filesystem_mountpoint == mountpoint }
        end
      end

      context "if no disk is enforced for '/'" do
        let(:root_device) { nil }
        let(:yaml_suffix) { "sdb_root_device" }

        include_examples "proposed layout"

        it "allocates the root device in the biggest suitable disk" do
          proposal.propose
          expect(disk_for("/").name).to eq "/dev/sdb"
        end
      end

      context "if a disk without free space is chosen for '/'" do
        let(:root_device) { "/dev/sda" }
        let(:yaml_suffix) { "sda_root_device" }

        include_examples "proposed layout"

        it "allocates in the root device the partitions that must be there" do
          proposal.propose
          expect(disk_for("/").name).to eq "/dev/sda"
        end

        it "allocates other partitions in the already available space" do
          proposal.propose
          expect(disk_for("/home").name).to eq "/dev/sdb"
          expect(disk_for("swap").name).to eq "/dev/sdb"
        end
      end

      context "if a disk with enough free space is chosen for '/'" do
        let(:root_device) { "/dev/sdb" }
        let(:yaml_suffix) { "sdb_root_device" }

        include_examples "proposed layout"

        it "allocates all the partitions there" do
          proposal.propose
          expect(disk_for("/").name).to eq "/dev/sdb"
          expect(disk_for("/home").name).to eq "/dev/sdb"
          expect(disk_for("swap").name).to eq "/dev/sdb"
        end
      end

      context "if '/' is placed in a GPT disk (legacy boot)" do
        let(:root_device) { "/dev/sdb" }

        it "creates a bios_boot partition if it's not there" do
          proposal.propose
          bios_boot = proposal.devices.partitions.select { |p| p.id.is?(:bios_boot) }

          expect(bios_boot).to_not be_empty
        end
      end

      context "if '/' is placed in a MBR disk (legacy boot)" do
        let(:root_device) { "/dev/sda" }

        it "does not create a bios_boot partition" do
          proposal.propose
          bios_boot = proposal.devices.partitions.select { |p| p.id.is?(:bios_boot) }

          expect(bios_boot).to be_empty
        end
      end
    end
  end

  describe "#failed?" do
    subject(:proposal) { described_class.new }

    before do
      allow(proposal).to receive(:proposed?).and_return(proposed)
      allow(proposal).to receive(:devices).and_return(devices)
    end

    let(:devices) { nil }

    context "when it is not proposed" do
      let(:proposed) { false }

      it "returns false" do
        expect(proposal.failed?).to be false
      end
    end

    context "when it is proposed" do
      let(:proposed) { true }

      context "and it has devices" do
        let(:devices) { double("Y2Storage::Devicegraph") }

        it "returns false" do
          expect(proposal.failed?).to be false
        end
      end

      context "and it has not devices" do
        let(:devices) { nil }

        it "returns true" do
          expect(proposal.failed?).to be true
        end
      end
    end
  end
end
