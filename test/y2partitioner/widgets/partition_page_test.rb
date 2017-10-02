require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/partition_page"

describe Y2Partitioner::Widgets::PartitionPage do
  let(:partition) { double("Partition", name: "/dev/hdz1", basename: "hdz1") }

  subject { described_class.new(partition) }

  include_examples "CWM::Page"
end
