#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/disk_expert_menu_button"

describe Y2Partitioner::Widgets::DiskExpertMenuButton do
  before do
    devicegraph_stub("empty_hard_disk_50GiB.yml")
  end

  subject(:button) { described_class.new(disk: disk) }

  let(:disk) { current_graph.find_by_name(device_name) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:device_name) { "/dev/sda" }

  include_examples "CWM::AbstractWidget"

  describe "#handle" do
    let(:event) { { "ID" => selected_option } }

    before do
      allow(Y2Partitioner::Actions::CreatePartitionTable).to receive(:new)
        .with(disk.name).and_return(create_partition_table_action)

      allow(Y2Partitioner::Actions::CloneDisk).to receive(:new)
        .with(disk).and_return(clone_disk_action)

      allow(create_partition_table_action).to receive(:run).and_return(result)
      allow(clone_disk_action).to receive(:run).and_return(result)
    end

    let(:create_partition_table_action) do
      instance_double(Y2Partitioner::Actions::CreatePartitionTable)
    end

    let(:clone_disk_action) do
      instance_double(Y2Partitioner::Actions::CloneDisk)
    end

    let(:result) { :finish }

    context "when 'create new partition table' is selected" do
      let(:selected_option) { :create_partition_table }

      it "opens the workflow for creating a partition table" do
        expect(create_partition_table_action).to receive(:run)
        button.handle(event)
      end

      context "when the workflow returns :finish" do
        let(:result) { :finish }

        it "returns :redraw" do
          expect(button.handle(event)).to eq(:redraw)
        end
      end

      context "when the workflow does not return :finish" do
        let(:result) { :back }

        it "returns nil" do
          expect(button.handle(event)).to be_nil
        end
      end
    end

    context "when 'clone disk' is selected" do
      let(:selected_option) { :clone_disk }

      it "opens the workflow for cloning the disk" do
        expect(clone_disk_action).to receive(:run)
        button.handle(event)
      end

      context "when the workflow returns :finish" do
        let(:result) { :finish }

        it "returns :redraw" do
          expect(button.handle(event)).to eq(:redraw)
        end
      end

      context "when the workflow does not return :finish" do
        let(:result) { :back }

        it "returns nil" do
          expect(button.handle(event)).to be_nil
        end
      end
    end

    context "when neither 'create partition table' nor 'clone disk' is selected" do
      let(:event) { { "ID" => "other event" } }

      it "returns nil" do
        expect(button.handle(event)).to be_nil
      end
    end
  end
end
