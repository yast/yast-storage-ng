#!/usr/bin/env rspec
# Copyright (c) [2018-2019] SUSE LLC
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
require "y2partitioner/actions/delete_bcache"

describe Y2Partitioner::Actions::DeleteBcache do
  def bcache_cset_only_for(bcache)
    bcache.bcache_cset.bcaches.each do |dev|
      dev.remove_bcache_cset if dev != bcache
    end
  end

  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(device) }

  let(:device) { Y2Storage::BlkDevice.find_by_name(device_graph, device_name) }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  describe "#run" do
    before do
      allow(Yast2::Popup).to receive(:show).and_return(accept)
    end

    let(:accept) { nil }

    shared_examples "not delete bcache" do
      it "does not delete the bcache" do
        subject.run

        expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to_not be_nil
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    shared_examples "confirm and delete bcache" do
      context "when the bcache is not being used (e.g., partitioned)" do
        before do
          device.remove_descendants
        end

        it "shows a simple confirm message" do
          expect(Yast2::Popup).to receive(:show).with(/Really delete/, anything)

          subject.run
        end
      end

      context "when the bcache is being used (e.g., partitioned)" do
        before do
          device.remove_descendants

          device.create_partition_table(Y2Storage::PartitionTables::Type::GPT)
          slot = device.partition_table.unused_partition_slots.first
          device.partition_table.create_partition(slot.name,
            slot.region, Y2Storage::PartitionType::PRIMARY)
        end

        it "shows a specific confirm message for recursive delete" do
          expect(subject).to receive(:confirm_recursive_delete).and_call_original

          subject.run
        end
      end

      context "when the confirm message is not accepted" do
        let(:accept) { :no }

        include_examples "not delete bcache"
      end

      context "when the confirm message is accepted" do
        let(:accept) { :yes }

        it "deletes the bcache" do
          subject.run

          expect(device_graph.find_by_name(device_name)).to be_nil
        end

        it "returns :finish" do
          expect(subject.run).to eq(:finish)
        end
      end
    end

    context "when the device is a flash-only bcache" do
      let(:scenario) { "bcache2.xml" }

      let(:device_name) { "/dev/bcache1" }

      it "shows an error message" do
        expect(Yast2::Popup).to receive(:show).with(/is a flash-only/, headline: :error)

        subject.run
      end

      include_examples "not delete bcache"
    end

    context "when the bcache already exists on disk" do
      let(:scenario) { "bcache1.xml" }

      let(:device_name) { "/dev/bcache1" }

      let(:system_device) { Y2Partitioner::DeviceGraphs.instance.system.find_device(device.sid) }

      context "and it had a caching set on disk" do
        before do
          # Only to ensure the pre-condition is fulfilled
          expect(system_device.bcache_cset).to_not be_nil
        end

        context "and its caching set was shared with other bcaches" do
          before do
            # Only to ensure the pre-condition is fulfilled
            expect(system_device.bcache_cset.bcaches.size).to be > 1
          end

          it "shows an error message" do
            expect(Yast2::Popup).to receive(:show).with(/cannot be deleted/, headline: :error)

            subject.run
          end

          include_examples "not delete bcache"
        end

        context "and its caching set was not shared" do
          before do
            bcache_cset_only_for(system_device)
          end

          include_examples "confirm and delete bcache"
        end
      end

      context "and it had no caching set on disk" do
        before do
          system_device.remove_bcache_cset
        end

        context "and currently it has not caching set either" do
          before do
            device.remove_bcache_cset
          end

          include_examples "confirm and delete bcache"
        end

        context "and currently it has a caching set" do
          before do
            # Only to ensure the pre-condition is fulfilled
            expect(device.bcache_cset).to_not be_nil
          end

          include_examples "confirm and delete bcache"
        end
      end
    end

    context "when the bcache does not exist on disk" do
      let(:scenario) { "bcache1.xml" }

      let(:device_name) { "/dev/bcache99" }

      before do
        vda1 = device_graph.find_by_name("/dev/vda1")

        vda1.create_bcache(device_name)
      end

      include_examples "confirm and delete bcache"
    end
  end
end
