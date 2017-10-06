require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::Partition do
  before { devicegraph_stub("one-empty-disk.yml") }

  let(:partition) { double("Partition", name: "/dev/hdz1", basename: "hdz1") }

  subject { described_class.new(partition) }

  include_examples "CWM::Page"
end
