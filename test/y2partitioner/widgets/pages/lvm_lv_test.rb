require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages/lvm_lv"

describe Y2Partitioner::Widgets::Pages::LvmLv do
  before { devicegraph_stub("one-empty-disk.yml") }

  let(:lvm_lv) { double("LvmLv", name: "Baggins", lv_name: "Bilbo") }

  subject { described_class.new(lvm_lv) }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    it "shows a button to edit a vg or lv" do
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
