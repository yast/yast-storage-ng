require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/partition_size"
require "y2partitioner/sequences/add_partition"

describe "Partition Size widgets" do
  let(:controller) do
    pt = Y2Partitioner::Sequences::PartitionController.new("/dev/sda")
    pt.region = region
    pt.custom_size = Y2Storage::DiskSize.MiB(1)
    pt
  end
  let(:region) { Y2Storage::Region.create(2000, 1000, Y2Storage::DiskSize.new(1500)) }
  let(:slot) { double("PartitionSlot", region: region) }
  before { allow(controller).to receive(:unused_slots).and_return [slot] }
  let(:regions) { [region] }

  describe Y2Partitioner::Dialogs::PartitionSize do
    subject { described_class.new(controller) }

    before do
      allow(Y2Partitioner::Dialogs::PartitionSize::SizeWidget)
        .to receive(:new).and_return(term(:Empty))
    end
    include_examples "CWM::Dialog"
  end

  describe Y2Partitioner::Dialogs::PartitionSize::SizeWidget do
    subject { described_class.new(controller, regions) }

    include_examples "CWM::CustomWidget"
  end

  describe Y2Partitioner::Dialogs::PartitionSize::CustomSizeInput do
    subject { described_class.new(controller, regions) }

    before do
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
        allow(subject).to receive(:value)
          .and_return Y2Storage::DiskSize.new(2_000_000)
      end

      it "pops up an error when the size is too big" do
        expect(Yast::Popup).to receive(:Error)
        expect(Yast::UI).to receive(:SetFocus)
        expect(subject.validate).to eq false
      end
    end
  end

  describe Y2Partitioner::Dialogs::PartitionSize::CustomRegion do
    before do
      allow(subject).to receive(:query_widgets).and_return [2200, 2500]
    end

    subject { described_class.new(controller, regions) }

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
  end
end
