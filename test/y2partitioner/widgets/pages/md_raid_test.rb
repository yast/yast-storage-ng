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

    describe "#contents" do
      let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

      it "shows a button to edit the raid" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDeviceEditButton) }
        expect(button).to_not be_nil
      end

      it "shows a button to resize the raid" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DeviceResizeButton) }
        expect(button).to_not be_nil
      end

      it "shows a button to delete the raid" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DeviceDeleteButton) }
        expect(button).to_not be_nil
      end
    end
  end
end
