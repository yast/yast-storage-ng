require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/format_and_mount"

describe Y2Partitioner::Dialogs::FormatAndMount do
  let(:controller) { double("FilesystemController", blk_device: partition, filesystem: nil) }
  let(:partition) { double("Partition", name: "/dev/sda1") }

  subject { described_class.new(controller) }

  include_examples "CWM::Dialog"
end

describe Y2Partitioner::Dialogs::FormatAndMount::FormatMountOptions do
  let(:controller) { double("FilesystemController", filesystem: nil) }
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
