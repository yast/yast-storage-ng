require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages/lvm_vg"

describe Y2Partitioner::Widgets::Pages::LvmVg do
  before { devicegraph_stub("lvm-two-vgs.yml") }

  subject { described_class.new(lvm_vg, pager) }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:lvm_vg) { device_graph.lvm_vgs.first }

  let(:pager) { double("Pager") }

  include_examples "CWM::Page"

  describe Y2Partitioner::Widgets::Pages::LvmVgTab do
    subject { described_class.new(lvm_vg) }

    include_examples "CWM::Tab"
  end

  describe Y2Partitioner::Widgets::Pages::LvmLvTab do
    subject { described_class.new(lvm_vg, pager) }

    include_examples "CWM::Tab"

    describe "#contents" do
      let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

      it "shows a table with the lvs of a vg" do
        table = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::LvmDevicesTable) }

        expect(table).to_not be_nil

        devices = lvm_vg.lvm_lvs.map(&:name)
        items = table.items.map { |i| i[1] }

        expect(items.sort).to eq(devices.sort)
      end

      it "shows a menu button to create a new lv" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::LvmLvAddButton) }
        expect(button).to_not be_nil
      end

      it "shows a button to edit a lv" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::LvmEditButton) }
        expect(button).to_not be_nil
      end

      it "shows a resize button" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DeviceResizeButton) }
        expect(button).to_not be_nil
      end

      it "shows a delete button" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DeviceDeleteButton) }
        expect(button).to_not be_nil
      end
    end
  end

  describe Y2Partitioner::Widgets::Pages::LvmPvTab do
    subject { described_class.new(lvm_vg, pager) }

    include_examples "CWM::Tab"
  end
end
