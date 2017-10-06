require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::MdRaid do
  before { devicegraph_stub("one-empty-disk.yml") }

  let(:pager) { double("Pager") }

  let(:md) { double("Disk", name: "mymd", basename: "md", devices: []) }

  subject { described_class.new(md, pager) }

  include_examples "CWM::Page"

  describe Y2Partitioner::Widgets::Pages::MdTab do
    subject { described_class.new(md) }

    include_examples "CWM::Tab"
  end

  describe Y2Partitioner::Widgets::Pages::MdUsedDevicesTab do
    subject { described_class.new(md, pager) }

    include_examples "CWM::Tab"
  end
end
