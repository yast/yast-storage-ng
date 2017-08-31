require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/md_raids_page"

describe Y2Partitioner::Widgets::MdRaidsPage do
  subject { described_class.new(pager) }

  let(:pager) { double("OverviewTreePager") }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    # TODO: reader/writer for Mds
    it "shows a table with the raids" do
      table = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDevicesTable) }

      expect(table).to_not be_nil
    end
  end
end
