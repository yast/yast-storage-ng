require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/blk_devices_table"

describe Y2Partitioner::Widgets::BlkDevicesTable do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(devices, pager) }

  let(:devices) { device_graph.disks }

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

  describe "#selected_device" do
    context "when the table is empty" do
      before do
        allow(subject).to receive(:items).and_return([])
      end

      it "returns nil" do
        expect(subject.selected_device).to be_nil
      end
    end

    context "when the table is not empty" do
      context "and there is no selected row" do
        before do
          allow(subject).to receive(:value).and_return(nil)
        end

        it "returns nil" do
          expect(subject.selected_device).to be_nil
        end
      end

      context "and a row is selected" do
        before do
          allow(subject).to receive(:value).and_return("table:partition:#{selected_device.sid}")
        end

        let(:selected_device) do
          Y2Storage::BlkDevice.find_by_name(device_graph, selected_device_name)
        end

        let(:selected_device_name) { "/dev/sda2" }

        it "returns the selected device" do
          device = subject.selected_device

          expect(device).to eq(selected_device)
        end
      end
    end
  end
end
