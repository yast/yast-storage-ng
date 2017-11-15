require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/blk_device_edit_button"

describe Y2Partitioner::Widgets::BlkDeviceEditButton do
  let(:device) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, "/dev/sda2") }
  let(:sequence) { double("EditBlkDevice", run: :result) }

  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
    allow(Y2Partitioner::Actions::EditBlkDevice).to receive(:new).and_return sequence
  end

  include_examples "CWM::PushButton"

  context "when defined for a concrete device" do
    subject(:button) { described_class.new(device: device) }

    describe "#handle" do
      it "opens the edit workflow for the device" do
        expect(Y2Partitioner::Actions::EditBlkDevice).to receive(:new).with(device)
        button.handle
      end

      it "returns :redraw if the workflow returns :finish" do
        allow(sequence).to receive(:run).and_return :finish
        expect(button.handle).to eq :redraw
      end

      it "returns nil if the workflow does not return :finish" do
        allow(sequence).to receive(:run).and_return :back
        expect(button.handle).to be_nil
      end
    end
  end

  context "when defined for a table" do
    let(:table) { double("table") }

    subject(:button) { described_class.new(table: table) }

    describe "#handle" do
      context "when no device is selected in the table" do
        before { allow(table).to receive(:selected_device).and_return(nil) }

        it "shows an error message" do
          expect(Yast::Popup).to receive(:Error)
          button.handle
        end

        it "does not open the edit workflow" do
          expect(Y2Partitioner::Actions::EditBlkDevice).to_not receive(:new)
          button.handle
        end

        it "returns nil" do
          expect(button.handle).to be(nil)
        end
      end

      context "when a device is selected in the table" do
        before { allow(table).to receive(:selected_device).and_return(device) }

        it "opens the edit workflow for the device" do
          expect(Y2Partitioner::Actions::EditBlkDevice).to receive(:new).with(device)
          button.handle
        end

        it "returns :redraw if the workflow returns :finish" do
          allow(sequence).to receive(:run).and_return :finish
          expect(button.handle).to eq :redraw
        end

        it "returns nil if the workflow does not return :finish" do
          allow(sequence).to receive(:run).and_return :back
          expect(button.handle).to be_nil
        end
      end
    end
  end
end
