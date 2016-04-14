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
require "storage/proposal"
require "storage/refinements/test_devicegraph"
require "storage/refinements/size_casts"
require "storage/boot_requirements_checker"

describe Yast::Storage::Proposal do
  describe "#propose" do
    using Yast::Storage::Refinements::TestDevicegraph
    using Yast::Storage::Refinements::SizeCasts

    before do
      fake_scenario(scenario)
      allow(Yast::Storage::BootRequirementsChecker).to receive(:new).and_return boot_checker
      allow(Yast::Storage::DiskAnalyzer).to receive(:new).and_return disk_analyzer
      allow(disk_analyzer).to receive(:windows_partitions).and_return windows_partitions
      allow_any_instance_of(::Storage::Filesystem).to receive(:detect_resize_info)
        .and_return(resize_info)
    end

    subject(:proposal) { described_class.new(settings: settings) }

    let(:disk_analyzer) { Yast::Storage::DiskAnalyzer.new }
    let(:boot_checker) do
      instance_double("Yast::Storage::BootRequirementChecker", needed_partitions: [])
    end
    let(:resize_info) do
      instance_double("::Storage::ResizeInfo", resize_ok: true, min_size_k: 40.GiB.size_k)
    end
    let(:settings) do
      settings = Yast::Storage::Proposal::Settings.new
      settings.use_separate_home = separate_home
      settings
    end

    let(:expected) do
      if separate_home
        ::Storage::Devicegraph.new_from_file(output_file_for("#{scenario}-sep-home"))
      else
        ::Storage::Devicegraph.new_from_file(output_file_for(scenario))
      end
    end

    context "in a windows-only PC" do
      let(:scenario) { "windows-pc" }
      let(:windows_partitions) { { "/dev/sda" => [analyzer_part("/dev/sda1")] } }

      context "with a separate home" do
        let(:separate_home) { true }

        it "proposes the expected layout" do
          proposal.propose
          expect(proposal.devices.to_str).to eq expected.to_str
        end
      end

      context "without separate home" do
        let(:separate_home) { false }

        it "proposes the expected layout" do
          proposal.propose
          expect(proposal.devices.to_str).to eq expected.to_str
        end
      end
    end

    context "in a windows/linux multiboot PC" do
      let(:scenario) { "windows-linux-multiboot-pc" }
      let(:windows_partitions) { { "/dev/sda" => [analyzer_part("/dev/sda1")] } }

      context "with a separate home" do
        let(:separate_home) { true }

        it "proposes the expected layout" do
          proposal.propose
          expect(proposal.devices.to_str).to eq expected.to_str
        end
      end

      context "without separate home" do
        let(:separate_home) { false }

        it "proposes the expected layout" do
          proposal.propose
          expect(proposal.devices.to_str).to eq expected.to_str
        end
      end
    end

    context "in a linux multiboot PC" do
      let(:scenario) { "multi-linux-pc" }
      let(:windows_partitions) { {} }

      context "with a separate home" do
        let(:separate_home) { true }

        it "proposes the expected layout" do
          proposal.propose
          expect(proposal.devices.to_str).to eq expected.to_str
        end
      end

      context "without separate home" do
        let(:separate_home) { false }

        it "proposes the expected layout" do
          proposal.propose
          expect(proposal.devices.to_str).to eq expected.to_str
        end
      end
    end
  end
end
