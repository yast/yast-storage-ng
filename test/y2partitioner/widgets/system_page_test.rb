require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/system_page"

describe Y2Partitioner::Widgets::SystemPage do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:devices) { Y2Storage::BlkDevice.all(device_graph) }

  subject { described_class.new(pager) }

  let(:pager) { double("OverviewTreePager") }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    it "shows a table with all devices" do
      table = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDevicesTable) }

      expect(table).to_not be_nil

      devices_name = devices.map(&:name)
      items_name = table.items.map { |i| i[1] }

      expect(items_name.sort).to eq(devices_name.sort)
    end
  end
end
