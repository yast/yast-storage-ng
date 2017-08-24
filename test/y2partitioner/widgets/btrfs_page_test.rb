require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/btrfs_page"

describe Y2Partitioner::Widgets::BtrfsPage do

  subject { described_class.new }

  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    it "shows a table with the btrfs filesystems" do
      table = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BtrfsTable) }

      expect(table).to_not be_nil
      expect(table.items.size).to eq(3)
    end

    it "shows a edit btrfs button" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BtrfsEditButton) }
      expect(button).to_not be_nil
    end
  end
end
