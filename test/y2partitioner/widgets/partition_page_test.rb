require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/partition_page"

describe Y2Partitioner::Widgets::PartitionPage do
  let(:partition) { double("Partition", name: "/dev/hdz1", basename: "hdz1") }

  subject { described_class.new(partition) }

  include_examples "CWM::Page"
end

describe Y2Partitioner::Widgets::PartitionPage::EditButton do
  subject { described_class.new("/dev/hdz1") }
  before do
    allow(Y2Storage::Partition) .to receive(:find_by_name)
    allow(Y2Partitioner::Sequences::EditBlkDevice)
      .to receive(:new).and_return(double(run: :next))
  end

  include_examples "CWM::PushButton"
end
