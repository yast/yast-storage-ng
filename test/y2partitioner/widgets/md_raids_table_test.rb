require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/md_raids_table"

describe Y2Partitioner::Widgets::MdRaidsTable do
  before do
    devicegraph_stub("md2-devicegraph.xml")
  end

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(devices, pager) }

  let(:devices) { device_graph.md_raids }

  let(:pager) { double("Pager") }

  # FIXME: default tests check that all column headers are strings, but they also can be a Yast::Term
  # include_examples "CWM::Table"

  describe "#header" do
    it "returns array" do
      expect(subject.header).to be_a(::Array)
    end
  end

  describe "#items" do
    it "returns array of arrays" do
      expect(subject.items).to be_a(::Array)
      expect(subject.items.first).to be_a(::Array)
    end
  end
end
