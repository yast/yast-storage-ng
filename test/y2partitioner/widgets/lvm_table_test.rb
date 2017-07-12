require_relative "../test_helper"

require "y2partitioner/widgets/lvm_table"

describe Y2Partitioner::Widgets::LvmTable do
  subject { described_class.new(devices, pager) }

  let(:devices) do
    graph = devicegraph_stub("complex-lvm-encrypt.yml").probed
    Y2Storage::LvmVg.all(graph) + Y2Storage::LvmLv.all(graph)
  end

  let(:pager) { double("Pager") }

  before do
    allow(Yast::UI).to receive(:GetDisplayInfo).and_return("HasIconSupport" => true)
  end

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
