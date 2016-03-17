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
require "storage/fake_probing"
require "storage/fake_device_factory"
require "storage/refinements/test_devicegraph"

describe Yast::Storage::Proposal do
  describe "#propose" do
    using Yast::Storage::Refinements::TestDevicegraph

    def input_file_for(name)
      File.join(DATA_PATH, "input", "#{name}.yml")
    end

    def output_file_for(name)
      File.join(DATA_PATH, "output", "#{name}.yml")
    end

    def fake_scenario(scenario)
      fake_probing = Yast::Storage::FakeProbing.new
      devicegraph = fake_probing.devicegraph
      Yast::Storage::FakeDeviceFactory.load_yaml_file(devicegraph, input_file_for(scenario))
      fake_probing.to_probed
    end

    before do
      fake_scenario(scenario)
    end

    subject(:proposal) { described_class.new(settings: settings) }

    let(:settings) do
      settings = Yast::Storage::Proposal::Settings.new
      settings.use_separate_home = separate_home
      settings
    end

    let(:result) do
      if separate_home
        ::Storage::Devicegraph.new_from_file(output_file_for("#{scenario}-sep-home"))
      else
        ::Storage::Devicegraph.new_from_file(output_file_for(scenario))
      end
    end

    context "in a windows-only PC" do
      let(:scenario) { "windows-pc" }

      context "with a separate home" do
        let(:separate_home) { true }

        it "proposes the expected layout" do
          proposal.propose
          expect(proposal.devices.to_str).to eq result.to_str
        end
      end

      context "without separate home" do
        let(:separate_home) { false }

        it "proposes the expected layout" do
          proposal.propose
          expect(proposal.devices.to_str).to eq result.to_str
        end
      end
    end

    context "in a windows/linux multiboot PC" do
      let(:scenario) { "windows-linux-multiboot-pc" }

      context "with a separate home" do
        let(:separate_home) { true }

        it "proposes the expected layout" do
          proposal.propose
          expect(proposal.devices.to_str).to eq result.to_str
        end
      end

      context "without separate home" do
        let(:separate_home) { false }

        it "proposes the expected layout" do
          proposal.propose
          expect(proposal.devices.to_str).to eq result.to_str
        end
      end
    end

    context "in a linux multiboot PC" do
      let(:scenario) { "multi-linux-pc" }

      context "with a separate home" do
        let(:separate_home) { true }

        it "proposes the expected layout" do
          proposal.propose
          expect(proposal.devices.to_str).to eq result.to_str
        end
      end

      context "without separate home" do
        let(:separate_home) { false }

        it "proposes the expected layout" do
          proposal.propose
          expect(proposal.devices.to_str).to eq result.to_str
        end
      end
    end
  end
end
