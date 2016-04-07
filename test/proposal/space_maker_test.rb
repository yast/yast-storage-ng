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

require_relative "../spec_helper"
require "storage/proposal"
require "storage/refinements/devicegraph_lists"
require "storage/refinements/size_casts"

describe Yast::Storage::Proposal::SpaceMaker do
  describe "#make_space" do
    using Yast::Storage::Refinements::SizeCasts
    using Yast::Storage::Refinements::DevicegraphLists

    before do
      fake_scenario(scenario)
    end

    let(:analyzer) do
      disk_analyzer = Yast::Storage::DiskAnalyzer.new
      disk_analyzer.analyze(fake_devicegraph)
      disk_analyzer
    end
    let(:settings) do
      settings = Yast::Storage::Proposal::Settings.new
      settings.candidate_devices = ["/dev/sda"]
      settings.root_device = "/dev/sda"
      settings
    end
    subject(:maker) { described_class.new(fake_devicegraph, analyzer, settings) }

    context "if the disk is not big enough" do
      let(:scenario) { "empty_hard_disk_50GiB" }
      let(:required_size) { 60.GiB }

      it "raises a NoDiskSpaceError exception" do
        expect { maker.provide_space(required_size) }
          .to raise_error Yast::Storage::Proposal::NoDiskSpaceError
      end
    end

    context "if there are windows and linux partitions" do
      let(:scenario) { "windows-linux-multiboot-pc" }
      let(:required_size) { 100.GiB }

      it "deletes some of the linux ones" do
        result = maker.provide_space(required_size)
        # FIXME: the result is actually kind of suboptimal, there were no need
        # to delete the swap partition
        expect(result.partitions).to contain_exactly(
          an_object_with_fields(label: "windows", size: 250.GiB)
        )
      end
    end
  end
end
