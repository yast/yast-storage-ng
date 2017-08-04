require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/btrfs_table"

describe Y2Partitioner::Widgets::BtrfsTable do
  subject { described_class.new(filesystems) }

  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  let(:filesystems) do
    Y2Partitioner::DeviceGraphs.instance.current.filesystems.select { |f| f.type.is?(:btrfs) }
  end

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

  describe "#selected_filesystem" do
    context "when the table is empty" do
      before do
        allow(subject).to receive(:items).and_return([])
      end

      it "returns nil" do
        expect(subject.selected_filesystem).to be_nil
      end
    end

    context "when the table is not empty" do
      context "and there is no selected row" do
        before do
          allow(subject).to receive(:value).and_return(nil)
        end

        it "returns nil" do
          expect(subject.selected_filesystem).to be_nil
        end
      end

      context "and a row is selected" do
        before do
          allow(subject).to receive(:value).and_return("table:partition:#{selected_device_name}")
        end

        let(:selected_device_name) { "/dev/sda2" }

        let(:selected_device) do
          devicegraph = Y2Partitioner::DeviceGraphs.instance.current
          Y2Storage::BlkDevice.find_by_name(devicegraph, selected_device_name)
        end

        it "returns the filesystems for the selected row" do
          filesystem = subject.selected_filesystem

          expect(filesystem).to be_a(Y2Storage::Filesystems::BlkFilesystem)
          expect(filesystem).to eq(selected_device.filesystem)
        end
      end
    end
  end
end
