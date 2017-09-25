require_relative "../test_helper"

require "cwm/rspec"
require "y2storage"
require "y2partitioner/dialogs/format_and_mount"
require "y2partitioner/sequences/filesystem_controller"

describe Y2Partitioner::Dialogs::FormatAndMount do
  before { devicegraph_stub("lvm-two-vgs.yml") }

  let(:blk_device) { Y2Storage::Partition.find_by_name(fake_devicegraph, "/dev/sda1") }
  let(:controller) do
    Y2Partitioner::Sequences::FilesystemController.new(blk_device, "")
  end

  subject { described_class.new(controller) }

  include_examples "CWM::Dialog"

  describe Y2Partitioner::Dialogs::FormatAndMount::FormatMountOptions do
    subject(:widget) { described_class.new(controller) }

    include_examples "CWM::CustomWidget"

    describe "#refresh_others" do
      let(:format_widget) { double("FormatOptions") }
      let(:mount_widget) { double("MountOptions") }

      before do
        allow(Y2Partitioner::Widgets::FormatOptions).to receive(:new).and_return format_widget
        allow(Y2Partitioner::Widgets::MountOptions).to receive(:new).and_return mount_widget
        allow(format_widget).to receive(:refresh)
        allow(mount_widget).to receive(:refresh)
      end

      context "when the FormatOptions widget triggers an update" do
        it "does not call #refresh for the widget triggering the update" do
          expect(format_widget).to_not receive(:refresh)
          widget.refresh_others(format_widget)
        end

        it "calls #refresh for the widget not triggering the update" do
          expect(mount_widget).to receive(:refresh)
          widget.refresh_others(format_widget)
        end
      end

      context "when the MountOptions widget triggers an update" do
        it "does not call #refresh for the widget triggering the update" do
          expect(mount_widget).to_not receive(:refresh)
          widget.refresh_others(mount_widget)
        end

        it "calls #refresh for the widget not triggering the update" do
          expect(format_widget).to receive(:refresh)
          widget.refresh_others(mount_widget)
        end
      end
    end
  end
end
