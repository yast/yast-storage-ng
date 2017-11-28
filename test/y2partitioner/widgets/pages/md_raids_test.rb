require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::MdRaids do
  before { devicegraph_stub(scenario) }

  subject { described_class.new(pager) }

  let(:pager) { double("OverviewTreePager") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:scenario) { "md_raid.xml" }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    let(:table) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDevicesTable) } }

    let(:items) { table.items.map { |i| i[1] } }

    it "shows a button to add a raid" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::MdAddButton) }
      expect(button).to_not be_nil
    end

    it "shows a button to edit a raid" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDeviceEditButton) }
      expect(button).to_not be_nil
    end

    it "shows a button to resize a raid" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DeviceResizeButton) }
      expect(button).to_not be_nil
    end

    it "shows a button to delete a raid" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DeviceDeleteButton) }
      expect(button).to_not be_nil
    end

    # TODO: reader/writer for Mds
    it "shows a table with the raids" do
      table = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDevicesTable) }
      expect(table).to_not be_nil
    end

    context "when there are Software RAIDs" do
      let(:scenario) { "md_raid.xml" }

      before do
        Y2Storage::Md.create(current_graph, "/dev/md1")
      end

      it "contains all Software RAIDs" do
        expect(items).to include(
          "/dev/md/md0",
          "/dev/md1"
        )
      end
    end

    context "when there is no Software RAID" do
      let(:scenario) { "md-imsm1-devicegraph.xml" }

      it "does not contain any device" do
        expect(items).to be_empty
      end
    end
  end
end
