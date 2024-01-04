#!/usr/bin/env rspec
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
require_relative "#{TEST_PATH}/support/proposal_examples"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::GuidedProposal do
  using Y2Storage::Refinements::SizeCasts

  before do
    allow(Yast::Kernel).to receive(:propose_hibernation?).and_return(true)
  end

  describe "#propose" do
    include_context "proposal"

    subject(:proposal) { described_class.new(settings:) }
    let(:architecture) { :x86 }
    let(:control_file) { "legacy_settings.xml" }

    context "in a PC with no partition table" do
      let(:scenario) { "empty_hard_disk_50GiB" }
      let(:expected_scenario) { "empty_hard_disk_gpt_50GiB" }
      include_examples "all proposed layouts"
      include_examples "additional use_needed layouts"
    end

    context "in a windows-only PC with MBR partition table" do
      let(:scenario) { "windows-pc" }
      include_examples "all proposed layouts"
    end

    context "in a windows-only PC with 128 KiB of MBR gap" do
      let(:scenario) { "windows-pc-mbr128" }
      let(:separate_home) { false }

      context "using LVM (where a separate /boot would be needed)" do
        let(:lvm) { true }

        include_examples "proposed layout"
      end

      context "not using LVM (where a separate /boot is not needed)" do
        let(:lvm) { false }

        include_examples "proposed layout"
      end
    end

    context "in a windows/linux multiboot PC with MBR partition table" do
      let(:scenario) { "windows-linux-multiboot-pc" }
      include_examples "all proposed layouts"
      include_examples "additional use_needed layouts"
    end

    context "in a linux multiboot PC with MBR partition table" do
      let(:scenario) { "multi-linux-pc" }
      let(:windows_partitions) { {} }
      include_examples "all proposed layouts"
      include_examples "additional use_needed layouts"
    end

    context "in a windows/linux multiboot PC with pre-existing LVM and MBR partition table" do
      let(:scenario) { "windows-linux-lvm-pc" }
      include_examples "LVM-based proposed layouts"
      include_examples "partition-based proposed layouts"

      context "if the proposal is configured to not reuse volume groups" do
        before { settings.lvm_vg_reuse = false }

        let(:expected_scenario) { "windows-linux-lvm-noreuse" }
        include_examples "LVM-based proposed layouts"
      end
    end

    context "in a windows-only PC with GPT partition table" do
      let(:scenario) { "windows-pc-gpt" }

      include_examples "all proposed layouts"
    end

    context "in a 50 GiB Windows-only PC with GPT partition table" do
      let(:scenario) { "windows-pc-50GiB-gpt" }
      let(:windows_partitions) { [partition_double("/dev/sda1")] }
      let(:resize_info) do
        instance_double("Y2Storage::ResizeInfo", resize_ok?: true, min_size: 1.GiB, max_size: 50.GiB,
          reasons: 0, reason_texts: [])
      end

      # essential part of the example: Windows partition has been resized
      include_examples "partition-based proposed layouts"
    end

    context "in a windows/linux multiboot PC with GPT partition table" do
      let(:scenario) { "windows-linux-multiboot-pc-gpt" }

      include_examples "all proposed layouts"
      include_examples "additional use_needed layouts"
    end

    context "in a linux multiboot PC with GPT partition table" do
      let(:scenario) { "multi-linux-pc-gpt" }
      let(:windows_partitions) { {} }

      include_examples "all proposed layouts"
      include_examples "additional use_needed layouts"
    end

    context "in a windows/linux multiboot PC with pre-existing LVM and GPT partition table" do
      let(:scenario) { "windows-linux-lvm-pc-gpt" }

      include_examples "LVM-based proposed layouts"
      include_examples "partition-based proposed layouts"
    end

    context "in a PC with an empty partition table" do
      let(:scenario) { "empty_hard_disk_mbr_50GiB" }
      let(:expected_scenario) { "empty_hard_disk_gpt_50GiB" }

      include_examples "all proposed layouts"
    end

    context "in a PC with an empty GPT partition table" do
      let(:scenario) { "empty_hard_disk_gpt_50GiB" }

      include_examples "all proposed layouts"

      context "when the partitioning section has :ng format" do
        let(:settings_format) { :ng }

        let(:control_file_content) do
          {
            "partitioning" => {
              "proposal" => {
                "lvm" => lvm
              },
              "volumes"  => volumes
            }
          }
        end

        let(:root) do
          {
            "mount_point"  => "/",
            "fs_type"      => "ext4",
            "min_size"     => "5 GiB",
            "max_size"     => "unlimited",
            "desired_size" => "15 GiB",
            "weight"       => 70
          }
        end

        let(:swap) do
          {
            "mount_point"   => "swap",
            "fs_type"       => "swap",
            "min_size"      => "2 GiB",
            "max_size"      => "8 GiB",
            "desired_size"  => "4 GiB",
            "weight"        => 30,
            "adjust_by_ram" => true
          }
        end

        let(:docker) do
          {
            "mount_point"  => "/var/lib/docker",
            "fs_type"      => "btrfs",
            "min_size"     => "5 GiB",
            "max_size"     => "20 GiB",
            "desired_size" => "15 GiB",
            "weight"       => 30
          }
        end

        context "using LVM" do
          let(:lvm) { true }

          # Regresion test to check that lvm volumes are generated with correct names
          context "with root and docker data volumes" do
            let(:volumes) { [root, docker] }

            let(:expected_scenario) { "empty_hard_disk_gpt_50GiB-root-docker" }

            it "proposes the expected layout" do
              proposal.propose
              expect(proposal.devices.to_str).to eq expected.to_str
            end
          end
        end

        context "not using LVM" do
          let(:lvm) { false }

          # Regression test to check the usage of system ram size instead of a fixed value
          context "with root and swap (with adjust_by_ram) volumes" do
            let(:volumes) { [root, swap] }

            # RAM size is 16 GiB
            let(:memtotal) { 16.GiB.to_i / 1.KiB.to_i }

            let(:expected_scenario) { "empty_hard_disk_gpt_50GiB-root-swap" }

            it "proposes the expected layout" do
              proposal.propose
              expect(proposal.devices.to_str).to eq expected.to_str
            end
          end
        end
      end
    end

    # Regression test for bug#1071949 in which no proposal was provided
    context "if the whole disk is used as PV (no partition table)" do
      let(:scenario) { "lvm-disk-as-pv.xml" }

      context "using LVM" do
        let(:lvm) { true }

        it "deletes the existing VG and proposes a new LVM layout" do
          expect(fake_devicegraph.partitions).to be_empty
          proposal.propose
          expect(proposal.devices.partitions).to_not be_empty
          expect(proposal.devices.lvm_vgs).to_not be_empty
        end
      end

      context "not using LVM" do
        let(:lvm) { false }

        it "deletes the existing LVM and proposes a new partition-based layout" do
          expect(fake_devicegraph.partitions).to be_empty
          proposal.propose
          expect(proposal.devices.partitions).to_not be_empty
          expect(proposal.devices.lvm_vgs).to be_empty
        end
      end
    end
  end
end
