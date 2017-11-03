require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::MdRaids do
  before { devicegraph_stub("one-empty-disk.yml") }

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

    it "shows a button to add a raid" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::Pages::MdRaids::AddButton) }
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
  end
end

describe Y2Partitioner::Widgets::Pages::MdRaids::AddButton do
  subject(:button) { described_class.new }

  let(:sequence) { double("AddMd") }

  before do
    devicegraph_stub("one-empty-disk.yml")
    allow(Y2Partitioner::Actions::AddMd).to receive(:new).and_return sequence
    allow(sequence).to receive(:run)
  end

  include_examples "CWM::PushButton"

  describe "#handle" do
    it "starts an AddMd sequence" do
      expect(sequence).to receive(:run)
      button.handle
    end

    it "returns :redraw if the sequence returns :finish" do
      allow(sequence).to receive(:run).and_return :finish
      expect(button.handle).to eq :redraw
    end

    it "returns nil if the sequence does not return :finish" do
      allow(sequence).to receive(:run).and_return :back
      expect(button.handle).to be_nil
    end
  end
end
