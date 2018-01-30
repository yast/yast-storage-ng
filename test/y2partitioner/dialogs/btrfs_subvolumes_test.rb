require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/btrfs_subvolumes"

describe Y2Partitioner::Dialogs::BtrfsSubvolumes do
  before { Y2Storage::StorageManager.create_test_instance }

  subject { described_class.new(filesystem) }

  let(:filesystem) { instance_double(Y2Storage::Filesystems::BlkFilesystem) }

  include_examples "CWM::Dialog"

  describe "#contents" do
    it "has a btrfs subvolumes widget" do
      expect(Y2Partitioner::Widgets::BtrfsSubvolumes).to receive(:new)
      subject.contents
    end
  end

  describe "#run" do
    before do
      allow_any_instance_of(Y2Partitioner::Dialogs::Popup).to receive(:run).and_return(result)
    end

    context "when the result is accepted" do
      let(:result) { :ok }

      it "stores the new devicegraph with all its changes" do
        previous_graph = Y2Partitioner::DeviceGraphs.instance.current
        subject.run
        current_graph = Y2Partitioner::DeviceGraphs.instance.current

        expect(current_graph.object_id).to_not eq(previous_graph.object_id)
      end
    end

    context "when the result is not accepted" do
      let(:result) { :cancel }

      it "keeps the initial devicegraph" do
        previous_graph = Y2Partitioner::DeviceGraphs.instance.current
        subject.run
        current_graph = Y2Partitioner::DeviceGraphs.instance.current

        expect(current_graph.object_id).to eq(previous_graph.object_id)
        expect(current_graph).to eq(previous_graph)
      end
    end
  end
end
