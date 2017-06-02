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
  describe "#propose" do
    include_context "proposal"

    subject(:proposal) { described_class.new(settings: settings) }
    let(:architecture) { :x86 }

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
            expect { proposal.propose }.to raise_error Y2Storage::Error
          end
        end

        context "without separate home" do
          let(:separate_home) { false }

          it "fails to make a proposal" do
            expect { proposal.propose }.to raise_error Y2Storage::Error
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
  end
end
