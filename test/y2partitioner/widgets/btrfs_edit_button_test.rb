require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/btrfs_edit_button"

describe Y2Partitioner::Widgets::BtrfsEditButton do
  subject { described_class.new(table) }

  let(:table) do
    instance_double(Y2Partitioner::Widgets::BtrfsTable, selected_filesystem: selected_filesystem)
  end

  let(:selected_filesystem) { nil }

  include_examples "CWM::PushButton"

  describe "#handle" do
    context "when there is no selected item in the table" do
      let(:selected_filesystem) { nil }

      it "shows an error popup" do
        expect(Yast::Popup).to receive(:Error)
        subject.handle
      end
    end

    context "when there is a selected item in the table" do
      let(:selected_filesystem) do
        instance_double(Y2Storage::Filesystems::BlkFilesystem)
      end

      before do
        allow(Y2Partitioner::Dialogs::BtrfsSubvolumes).to receive(:new).and_return(dialog)
      end

      let(:dialog) { instance_double(Y2Partitioner::Dialogs::BtrfsSubvolumes, run: nil) }

      it "shows a btrfs subvolumes dialog" do
        expect(dialog).to receive(:run)
        subject.handle
      end
    end
  end
end
