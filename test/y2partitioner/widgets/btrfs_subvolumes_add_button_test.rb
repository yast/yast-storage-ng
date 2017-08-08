require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/btrfs_subvolumes_add_button"

describe Y2Partitioner::Widgets::BtrfsSubvolumesAddButton do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
    allow(Y2Partitioner::Dialogs::BtrfsSubvolume).to receive(:new).and_return(dialog)
  end

  let(:dialog) { instance_double(Y2Partitioner::Dialogs::BtrfsSubvolume, run: result, form: form) }

  let(:result) { :cancel }

  let(:form) { nil }

  subject { described_class.new(table) }

  let(:table) do
    instance_double(Y2Partitioner::Widgets::BtrfsSubvolumesTable, filesystem: filesystem, refresh: nil)
  end

  let(:filesystem) do
    devicegraph = Y2Partitioner::DeviceGraphs.instance.current
    Y2Storage::BlkDevice.find_by_name(devicegraph, "/dev/sda2").filesystem
  end

  include_examples "CWM::PushButton"

  describe "#handle" do
    it "shows a dialog to create a new btrfs subvolume" do
      expect(Y2Partitioner::Dialogs::BtrfsSubvolume).to receive(:new)
      expect(dialog).to receive(:run)

      subject.handle
    end

    context "when the dialog is accepted" do
      let(:result) { :ok }

      let(:form) { double("dialog form", path: "@/foo", nocow: true) }

      it "creates a new subvolume with correct path and nocow attribute" do
        subvolumes = filesystem.btrfs_subvolumes
        expect(subvolumes.map(&:path)).to_not include(form.path)

        subject.handle

        expect(filesystem.btrfs_subvolumes.size > subvolumes.size).to be(true)

        subvolume = filesystem.btrfs_subvolumes.detect { |s| s.path == form.path }
        expect(subvolume).to_not be_nil
        expect(subvolume.nocow?).to eq(form.nocow)
      end

      it "creates a new subvolume with correct mount point" do
        mountpoint = File.join(filesystem.mountpoint, "foo")

        subvolumes = filesystem.btrfs_subvolumes
        expect(subvolumes.map(&:mountpoint)).to_not include(mountpoint)

        subject.handle

        expect(filesystem.btrfs_subvolumes.map(&:mountpoint)).to include(mountpoint)
      end

      it "refreshes the table" do
        expect(table).to receive(:refresh)
        subject.handle
      end
    end

    context "when the dialog is not accepted" do
      let(:result) { :cancel }

      it "does not create a new subvolume" do
        subvolumes = filesystem.btrfs_subvolumes
        subject.handle

        expect(filesystem.btrfs_subvolumes).to eq(subvolumes)
      end

      it "does not refresh the table" do
        expect(table).to_not receive(:refresh)
        subject.handle
      end
    end
  end
end
