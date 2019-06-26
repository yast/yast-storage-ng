#!/usr/bin/env rspec
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
# find current contact information at www.suse.com.

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/partition_table_clone"
require "y2partitioner/actions/controllers/clone_partition_table"

describe Y2Partitioner::Dialogs::PartitionTableClone do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(controller) }

  let(:controller) { Y2Partitioner::Actions::Controllers::ClonePartitionTable.new(device) }

  let(:device) { current_graph.find_by_name(device_name) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:scenario) { "mixed_disks_clone.yml" }

  let(:device_name) { "/dev/sda" }

  include_examples "CWM::Dialog"

  describe Y2Partitioner::Dialogs::PartitionTableClone::DevicesSelector do
    subject(:widget) { described_class.new(controller) }

    before do
      allow(subject).to receive(:value).and_return(selected_devices)
      allow(Yast2::Popup).to receive(:show)
    end

    let(:selected_devices) { [] }

    let(:sda) { current_graph.find_by_name("/dev/sda") }

    let(:sdd) { current_graph.find_by_name("/dev/sdd") }

    include_examples "CWM::AbstractWidget"

    describe "#validate" do
      context "when there are no selected devices" do
        let(:selected_devices) { [] }

        it "shows an error popup" do
          expect(Yast2::Popup).to receive(:show)
          subject.validate
        end

        it "returns false" do
          expect(subject.validate).to eq(false)
        end
      end

      context "when there are selected devices" do
        context "and some selected device has partitions" do
          let(:selected_devices) { [sda.sid, sdd.sid] }

          before do
            allow(subject).to receive(:confirm_recursive_delete).and_return(accept)
          end

          let(:accept) { true }

          it "asks for confirmation" do
            expect(subject).to receive(:confirm_recursive_delete)
            subject.validate
          end

          context "and if the user accepts" do
            let(:accepts) { true }

            it "returns true" do
              expect(subject.validate).to eq(true)
            end
          end

          context "and if the user declines" do
            let(:accept) { false }

            it "returns false" do
              expect(subject.validate).to eq(false)
            end
          end
        end

        context "and none selected device has partitions" do
          let(:selected_devices) { [sdd.sid] }

          it "does not ask for confirmation" do
            expect(subject).to_not receive(:confirm_recursive_delete)
            subject.validate
          end

          it "returns true" do
            expect(subject.validate).to eq(true)
          end
        end
      end
    end

    describe "#store" do
      let(:selected_devices) { [sda.sid, sdd.sid] }

      it "saves selected devices into the controller" do
        expect(controller.selected_devices_for_cloning).to be_empty
        subject.store
        expect(controller.selected_devices_for_cloning.map(&:name))
          .to contain_exactly("/dev/sda", "/dev/sdd")
      end
    end
  end
end
