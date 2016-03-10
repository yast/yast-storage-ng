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
require "storage/yaml_writer"

describe Yast::Storage::Proposal do
  describe "#propose" do

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

    def result_for(name)
      devicegraph = ::Storage::Devicegraph.new
      Yast::Storage::FakeDeviceFactory.load_yaml_file(devicegraph, output_file_for(name))
      devicegraph
    end

    def devgraph_tree(devicegraph)
      writer = Yast::Storage::YamlWriter.new
      writer.yaml_device_tree(devicegraph)
    end

    def devgraph_str(devicegraph)
      tree = devgraph_tree(devicegraph)
      recursive_to_a(tree).to_s
    end

    def recursive_to_a(tree)
      return tree if tree.is_a?(Fixnum)
      return tree.dup unless tree.respond_to?(:to_a)
      res = tree.to_a
      res = res.map do |element|
        if element.is_a?(Array)
          element.map { |e| recursive_to_a(e) }
        else
          recursive_to_a(element)
        end
      end
      res.sort
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
        result_for("#{scenario}-sep-home")
      else
        result_for(scenario)
      end
    end

    context "in a windows-only PC" do
      let(:scenario) { "windows-pc" }

      context "with a separate home" do
        let(:separate_home) { true }

        it "proposes the expected layout" do
          proposal.propose
          expect(devgraph_str(proposal.devices)).to eq devgraph_str(result)
        end
      end

      context "without separate home" do
        let(:separate_home) { false }

        it "proposes the expected layout" do
          proposal.propose
          expect(devgraph_str(proposal.devices)).to eq devgraph_str(result)
        end
      end
    end

    context "in a windows/linux multiboot PC" do
      let(:scenario) { "windows-linux-multiboot-pc" }

      context "with a separate home" do
        let(:separate_home) { true }

        it "proposes the expected layout" do
          proposal.propose
          expect(devgraph_str(proposal.devices)).to eq devgraph_str(result)
        end
      end

      context "without separate home" do
        let(:separate_home) { false }

        it "proposes the expected layout" do
          proposal.propose
          expect(devgraph_str(proposal.devices)).to eq devgraph_str(result)
        end
      end
    end

    context "in a linux multiboot PC" do
      let(:scenario) { "multi-linux-pc" }

      context "with a separate home" do
        let(:separate_home) { true }

        it "proposes the expected layout" do
          proposal.propose
          expect(devgraph_str(proposal.devices)).to eq devgraph_str(result)
        end
      end

      context "without separate home" do
        let(:separate_home) { false }

        it "proposes the expected layout" do
          proposal.propose
          expect(devgraph_str(proposal.devices)).to eq devgraph_str(result)
        end
      end
    end
  end
end
