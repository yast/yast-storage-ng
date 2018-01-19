require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/partition_size"
require "y2partitioner/actions/add_partition"

describe "Partition Size widgets" do
  using Y2Storage::Refinements::SizeCasts

  let(:controller) do
    pt = Y2Partitioner::Actions::Controllers::Partition.new("/dev/sda")
    pt.region = region
    pt.custom_size = Y2Storage::DiskSize.MiB(1)
    pt
  end
  let(:region) { Y2Storage::Region.create(2000, 1000, Y2Storage::DiskSize.new(1500)) }
  let(:slot) { double("PartitionSlot", region: region) }
  before do
    allow(controller).to receive(:unused_slots).and_return [slot]
    allow(controller).to receive(:unused_optimal_slots).and_return [slot]
    allow(controller).to receive(:optimal_grain).and_return Y2Storage::DiskSize.MiB(1)
  end
  let(:regions) { [region] }
  let(:optimal_regions) { [region] }

  describe Y2Partitioner::Dialogs::PartitionSize do
    subject { described_class.new(controller) }

    before do
      allow(Y2Partitioner::Dialogs::PartitionSize::SizeWidget)
        .to receive(:new).and_return(term(:Empty))
    end
    include_examples "CWM::Dialog"
  end

  describe Y2Partitioner::Dialogs::PartitionSize::SizeWidget do
    subject { described_class.new(controller, regions, optimal_regions) }

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
      allow(subject).to receive(:query_widgets).and_return [2200, 2500]
    end

    subject { described_class.new(controller, regions, region) }

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
