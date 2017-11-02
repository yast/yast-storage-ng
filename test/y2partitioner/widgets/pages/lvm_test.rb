require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::Lvm do
  before do
    devicegraph_stub(scenario)
  end

  let(:scenario) { "lvm-two-vgs.yml" }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:devices) { (device_graph.lvm_vgs + device_graph.lvm_vgs.map(&:lvm_lvs)).flatten.compact }

  subject { described_class.new(pager) }

  let(:pager) { double("OverviewTreePager") }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    it "shows a table with the vgs devices and their lvs" do
      table = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::LvmDevicesTable) }

      expect(table).to_not be_nil

      devices_name = devices.map(&:name)
      items_name = table.items.map { |i| i[1] }

      expect(items_name.sort).to eq(devices_name.sort)
    end

    it "shows a menu button to create a new vg or lv" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::LvmAddButton) }
      expect(button).to_not be_nil
    end

    it "shows a button to edit a vg or lv" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::LvmEditButton) }
      expect(button).to_not be_nil
    end

    it "shows a button to resize a vg or lv" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::LvmResizeButton) }
      expect(button).to_not be_nil
    end

    it "shows a button to delete a vg or lv" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DeviceDeleteButton) }
      expect(button).to_not be_nil
    end
  end
end
