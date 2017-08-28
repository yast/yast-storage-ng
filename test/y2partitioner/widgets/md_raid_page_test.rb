require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/md_raid_page"

describe Y2Partitioner::Widgets::MdRaidPage do
  let(:pager) { double("Pager") }

  let(:md) { double("Disk", name: "mymd", basename: "md", devices: []) }

  subject { described_class.new(md, pager) }

  include_examples "CWM::Page"

  describe Y2Partitioner::Widgets::MdTab do
    subject { described_class.new(md) }

    include_examples "CWM::Tab"
  end

  describe Y2Partitioner::Widgets::MdUsedDevicesTab do
    subject { described_class.new(md, pager) }

    include_examples "CWM::Tab"
  end
end
