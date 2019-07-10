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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/partition_size"
require "y2partitioner/actions/add_partition"

describe "Partition Size widgets" do
  using Y2Storage::Refinements::SizeCasts

  let(:controller) do
    pt = Y2Partitioner::Actions::Controllers::AddPartition.new(disk)
    pt.custom_size = Y2Storage::DiskSize.MiB(1)
    pt.type = partition_type
    pt
  end
  let(:disk) { "/dev/sda" }

  let(:region_prim1) { Y2Storage::Region.create(2000, 1000, Y2Storage::DiskSize.new(1500)) }
  let(:region_log) { Y2Storage::Region.create(3001, 1000, Y2Storage::DiskSize.new(1500)) }
  let(:region_prim2) { Y2Storage::Region.create(4001, 1000, Y2Storage::DiskSize.new(1500)) }
  let(:slot_prim1) { double("PartitionSlot", region: region_prim1) }
  let(:slot_log) { double("PartitionSlot", region: region_log) }
  let(:slot_prim2) { double("PartitionSlot", region: region_prim2) }

  let(:partition_type) { Y2Storage::PartitionType::LOGICAL }
  let(:regions) { [region_log] }
  let(:optimal_regions) { [region_log] }

  before do
    allow(slot_prim1).to receive(:possible?) do |type|
      type != Y2Storage::PartitionType::LOGICAL
    end
    allow(slot_prim2).to receive(:possible?) do |type|
      type != Y2Storage::PartitionType::LOGICAL
    end
    allow(slot_log).to receive(:possible?) do |type|
      type == Y2Storage::PartitionType::LOGICAL
    end
  end

  describe Y2Partitioner::Dialogs::PartitionSize do
    subject(:dialog) { described_class.new(controller) }

    before do
      allow(Y2Partitioner::Dialogs::PartitionSize::SizeWidget)
        .to receive(:new).and_return(term(:Empty))
      allow(controller).to receive(:unused_slots).and_return [slot_prim1, slot_log, slot_prim2]
      allow(controller).to receive(:unused_optimal_slots).and_return [slot_prim1, slot_log, slot_prim2]
    end

    include_examples "CWM::Dialog"

    describe "#content" do
      context "when creating a primary partition" do
        let(:partition_type) { Y2Storage::PartitionType::PRIMARY }

        it "offers only the regions of the primary slots" do
          expect(Y2Partitioner::Dialogs::PartitionSize::SizeWidget).to receive(:new)
            .with(controller, [region_prim1, region_prim2], [region_prim1, region_prim2])

          dialog.contents
        end
      end

      context "when creating a logical partition" do
        let(:partition_type) { Y2Storage::PartitionType::LOGICAL }

        it "offers only the region of the logical slot" do
          expect(Y2Partitioner::Dialogs::PartitionSize::SizeWidget).to receive(:new)
            .with(controller, [region_log], [region_log])

          dialog.contents
        end
      end
    end
  end

  describe Y2Partitioner::Dialogs::PartitionSize::SizeWidget do
    subject { described_class.new(controller, regions, optimal_regions) }

    before do
      allow(controller).to receive(:optimal_grain).and_return Y2Storage::DiskSize.MiB(1)
    end

    include_examples "CWM::CustomWidget"
  end

  describe Y2Partitioner::Dialogs::PartitionSize::CustomSizeInput do
    subject { described_class.new(controller, regions) }

    before do
      allow(controller).to receive(:optimal_grain).and_return Y2Storage::DiskSize.MiB(1)
      allow(subject).to receive(:value).and_return nil
    end

    # include_examples "CWM::InputField"
    include_examples "CWM::AbstractWidget"

    describe "#region" do
      it "returns a Region" do
        expect(subject.region).to be_a Y2Storage::Region
      end
    end

    describe "#validate" do
      before do
        allow(subject).to receive(:value).and_return size
        allow(subject).to receive(:enabled?).and_return enabled
      end
      let(:enabled) { true }

      context "when the entered size is too big" do
        let(:size) { 2.TiB }

        it "returns false" do
          expect(subject.validate).to eq false
        end

        it "pops up an error" do
          expect(Yast::Popup).to receive(:Error)
          expect(Yast::UI).to receive(:SetFocus)
          subject.validate
        end

        context "but the widget is disabled" do
          let(:enabled) { false }

          it "returns true" do
            expect(subject.validate).to eq true
          end
        end
      end

      context "when the entered size is too small" do
        let(:size) { 0.1.KiB }

        it "returns false" do
          expect(subject.validate).to eq false
        end

        it "pops up an error" do
          expect(Yast::Popup).to receive(:Error)
          expect(Yast::UI).to receive(:SetFocus)
          subject.validate
        end

        context "but the widget is disabled" do
          let(:enabled) { false }

          it "returns true" do
            expect(subject.validate).to eq true
          end
        end
      end

      context "when the entered value is not a correct size" do
        let(:size) { nil }

        it "returns false" do
          expect(subject.validate).to eq false
        end

        it "pops up an error" do
          expect(Yast::Popup).to receive(:Error)
          expect(Yast::UI).to receive(:SetFocus)
          subject.validate
        end

        context "but the widget is disabled" do
          let(:enabled) { false }

          it "returns true" do
            expect(subject.validate).to eq true
          end
        end
      end

      context "when the entered value is a correct size" do
        let(:size) { 1.MiB }

        it "returns true" do
          expect(subject.validate).to eq true
        end
      end
    end
  end

  describe Y2Partitioner::Dialogs::PartitionSize::CustomRegion do
    before do
      allow(subject).to receive(:query_widgets).and_return [entered_start, entered_end]
    end
    let(:entered_start) { 2200 }
    let(:entered_end) { 2500 }

    subject { described_class.new(controller, regions, region_log) }

    include_examples "CWM::CustomWidget"

    describe "#region" do
      it "returns a Region" do
        expect(subject.region).to be_a Y2Storage::Region
      end
    end

    describe "#store" do
      it "does not change the partition template" do
        controller_before = controller.dup
        subject.store

        expect(controller.region).to_not eq(subject.region)
        expect(controller.region).to eq(controller_before.region)
      end
    end

    describe "#validate" do
      before do
        devicegraph_stub("dasd1.xml")
        allow(subject).to receive(:enabled?).and_return enabled
        graph = Y2Partitioner::DeviceGraphs.instance.current

        # Let's create a couple of slots at beginning and end
        dasd = graph.find_by_name(disk)
        dasd.partition_table.delete_partition("/dev/dasda3")
        dasd.partition_table.delete_partition("/dev/dasda1")
      end
      let(:disk) { "/dev/dasda" }
      let(:enabled) { true }

      context "when the entered start is not in one available region" do
        let(:entered_start) { 52000 }
        let(:entered_end) { 60000 }

        it "returns false" do
          expect(subject.validate).to eq false
        end

        it "pops up an error about wrong start block" do
          expect(Yast::Popup).to receive(:Error).with(/entered as start/)
          expect(Yast::UI).to receive(:SetFocus)
          subject.validate
        end

        context "but the widget is disabled" do
          let(:enabled) { false }

          it "returns true" do
            expect(subject.validate).to eq true
          end
        end
      end

      context "when the entered end is smaller than the start" do
        let(:entered_start) { 2600 }
        let(:entered_end) { 2200 }

        it "returns false" do
          expect(subject.validate).to eq false
        end

        it "pops up an error about wrong end block" do
          expect(Yast::Popup).to receive(:Error).with(/end block/)
          expect(Yast::UI).to receive(:SetFocus)
          subject.validate
        end

        context "but the widget is disabled" do
          let(:enabled) { false }

          it "returns true" do
            expect(subject.validate).to eq true
          end
        end
      end

      context "when the entered region overflows one of the available regions " do
        let(:entered_start) { 2600 }
        let(:entered_end) { 305000 }

        it "returns false" do
          expect(subject.validate).to eq false
        end

        it "pops up an error about collision with partitions" do
          expect(Yast::Popup).to receive(:Error).with(/collides/)
          expect(Yast::UI).to receive(:SetFocus)
          subject.validate
        end

        context "but the widget is disabled" do
          let(:enabled) { false }

          it "returns true" do
            expect(subject.validate).to eq true
          end
        end
      end

      context "when the entered end is not in an available region" do
        let(:entered_start) { 2600 }
        let(:entered_end) { 52000 }

        it "returns false" do
          expect(subject.validate).to eq false
        end

        it "pops up an error about collision with partitions" do
          expect(Yast::Popup).to receive(:Error).with(/collides/)
          expect(Yast::UI).to receive(:SetFocus)
          subject.validate
        end

        context "but the widget is disabled" do
          let(:enabled) { false }

          it "returns true" do
            expect(subject.validate).to eq true
          end
        end
      end

      context "when the entered region is too small for the alignment requirements" do
        let(:entered_start) { 2600 }
        let(:entered_end) { 2610 }

        it "returns false" do
          expect(subject.validate).to eq false
        end

        it "pops up an error about the region size" do
          expect(Yast::Popup).to receive(:Error).with(/too small/)
          expect(Yast::UI).to receive(:SetFocus)
          subject.validate
        end

        context "but the widget is disabled" do
          let(:enabled) { false }

          it "returns true" do
            expect(subject.validate).to eq true
          end
        end
      end

      context "when the entered region cannot be aligned despite having a valid size" do
        let(:entered_start) { 2000 }
        let(:entered_end) { 2014 }

        it "returns false" do
          expect(subject.validate).to eq false
        end

        it "pops up an error about the region being invalid" do
          expect(Yast::Popup).to receive(:Error).with(/Invalid region/)
          expect(Yast::UI).to receive(:SetFocus)
          subject.validate
        end

        context "but the widget is disabled" do
          let(:enabled) { false }

          it "returns true" do
            expect(subject.validate).to eq true
          end
        end
      end

      context "when the entered region is valid" do
        let(:entered_start) { 2048 }
        let(:entered_end) { 4096 }

        it "returns false" do
          expect(subject.validate).to eq true
        end
      end
    end
  end
end
