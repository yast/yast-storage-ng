require_relative "../test_helper"

require "y2partitioner/widgets/btrfs_subvolumes_table"

describe Y2Partitioner::Widgets::BtrfsSubvolumesTable do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  subject { described_class.new(filesystem) }

  let(:filesystem) do
    devicegraph = Y2Partitioner::DeviceGraphs.instance.current
    Y2Storage::BlkDevice.find_by_name(devicegraph, "/dev/sda2").filesystem
  end

  describe "#header" do
    it "returns array" do
      expect(subject.header).to be_a(::Array)
    end
  end

  describe "#items" do
    let(:paths) { subject.items.map { |i| i[1] } }

    it "returns array of arrays" do
      expect(subject.items).to be_a(::Array)
      expect(subject.items.first).to be_a(::Array)
    end

    it "does not include the top level subvolume" do
      top_level_subvolume = filesystem.top_level_btrfs_subvolume

      expect(paths).to_not include(top_level_subvolume.path)
    end

    it "does not include the default subvolume" do
      default_subvolume = filesystem.default_btrfs_subvolume

      expect(paths).to_not include(default_subvolume.path)
    end
  end

  describe "#selected_subvolume" do
    context "when the table is empty" do
      before do
        allow(subject).to receive(:items).and_return([])
      end

      it "returns nil" do
        expect(subject.selected_subvolume).to be_nil
      end
    end

    context "when the table is not empty" do
      context "and there is no selected row" do
        before do
          allow(subject).to receive(:value).and_return(nil)
        end

        it "returns nil" do
          expect(subject.selected_subvolume).to be_nil
        end
      end

      context "and a row is selected" do
        before do
          allow(subject).to receive(:value).and_return("table:subvolume:#{selected_subvolume}")
        end

        let(:selected_subvolume) { "@/home" }

        it "returns the btrfs subvolume selected" do
          expect(subject.selected_subvolume.path).to eq(selected_subvolume)
        end
      end
    end
  end

  describe "#refresh" do
    it "calls to #change_items" do
      expect(subject).to receive(:change_items)
      subject.refresh
    end
  end
end
