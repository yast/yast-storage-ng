require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::Disk do
  before do
    devicegraph_stub(scenario)
  end

  let(:scenario) { "one-empty-disk.yml" }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(disk, pager) }

  let(:disk) { current_graph.disks.first }

  let(:pager) { double("Pager") }

  include_examples "CWM::Page"

  describe "#contents" do
    context "when the device is not multipath" do
      it "shows a disk tab" do
        expect(Y2Partitioner::Widgets::Pages::DiskTab).to receive(:new)
        subject.contents
      end

      it "shows a partitions tab" do
        expect(Y2Partitioner::Widgets::Pages::PartitionsTab).to receive(:new)
        subject.contents
      end

      it "does not show a used devices tab" do
        expect(Y2Partitioner::Widgets::UsedDevicesTab).to_not receive(:new)
        subject.contents
      end
    end

    context "when the device is a multipath" do
      let(:scenario) { "empty-dasd-and-multipath.xml" }

      let(:disk) { current_graph.multipaths.first }

      it "shows a disk tab" do
        expect(Y2Partitioner::Widgets::Pages::DiskTab).to receive(:new)
        subject.contents
      end

      it "shows a partitions tab" do
        expect(Y2Partitioner::Widgets::Pages::PartitionsTab).to receive(:new)
        subject.contents
      end

      it "shows a used devices tab" do
        expect(Y2Partitioner::Widgets::UsedDevicesTab).to receive(:new)
        subject.contents
      end
    end
  end

  describe Y2Partitioner::Widgets::Pages::DiskTab do
    subject { described_class.new(disk) }

    include_examples "CWM::Tab"
  end

  describe Y2Partitioner::Widgets::Pages::PartitionsTab do
    subject { described_class.new(disk, pager) }

    include_examples "CWM::Tab"
  end

  describe Y2Partitioner::Widgets::Pages::PartitionsTab::AddButton do
    subject { described_class.new(disk, ui_table) }

    before do
      allow(Y2Partitioner::Sequences::AddPartition)
        .to receive(:new).and_return(double(run: :next))
    end

    let(:ui_table) do
      instance_double(Y2Partitioner::Widgets::BlkDevicesTable,
        value: "table:partition:/dev/hdf4", items: ["a", "b"])
    end

    include_examples "CWM::PushButton"
  end
end
