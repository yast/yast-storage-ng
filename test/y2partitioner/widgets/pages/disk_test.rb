require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::Disk do
  let(:pager) { double("Pager") }
  let(:disk) do
    double("Disk",
      name: "mydisk", basename: "sysmydisk",
      partitions: [], partition_table: partition_table)
  end
  let(:partition_table) do
    double("PartitionTable", unused_partition_slots: [])
  end
  let(:ui_table) do
    double("BlkDevicesTable", value: "table:partition:/dev/hdf4", items: ["a", "b"])
  end

  subject { described_class.new(disk, pager) }

  include_examples "CWM::Page"

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

    include_examples "CWM::PushButton"
  end
end
