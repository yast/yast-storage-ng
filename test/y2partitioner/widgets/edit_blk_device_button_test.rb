require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/edit_blk_device_button"

describe Y2Partitioner::Widgets::EditBlkDeviceButton do
  let(:device) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, "/dev/sda2") }
  let(:sequence) { double("EditBlkDevice", run: :result) }

  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
    allow(Y2Partitioner::Sequences::EditBlkDevice).to receive(:new).and_return sequence
  end

  context "when defined for a concrete device" do
    subject(:button) { described_class.new(device: device) }

    include_examples "CWM::PushButton"

    describe "#handle" do
      it "opens the edit workflow for the device" do
        expect(Y2Partitioner::Sequences::EditBlkDevice).to receive(:new).with(device)
        button.handle
      end

      it "returns :redraw independently of the workflow result" do
        expect(button.handle).to eq :redraw
      end
    end
  end

  context "when defined for a table" do
    let(:table) { double("table") }

    subject(:button) { described_class.new(table: table) }

    describe "#handle" do
      context "and no device is selected in the table" do
        before { allow(table).to receive(:selected_device).and_return(nil) }

        include_examples "CWM::PushButton"

        it "shows an error message" do
          expect(Yast::Popup).to receive(:Error)
          button.handle
        end

        it "does not open the edit workflow" do
          expect(Y2Partitioner::Sequences::EditBlkDevice).to_not receive(:new)
          button.handle
        end

        it "returns nil" do
          expect(button.handle).to be(nil)
        end
      end

      context "and a device is selected in the table" do
        before { allow(table).to receive(:selected_device).and_return(device) }

        include_examples "CWM::PushButton"

        describe "#handle" do
          it "opens the edit workflow for the device" do
            expect(Y2Partitioner::Sequences::EditBlkDevice).to receive(:new).with(device)
            button.handle
          end

          it "returns :redraw independently of the workflow result" do
            expect(button.handle).to eq :redraw
          end
        end
      end
    end
  end

  context "when no device or table is specified" do
    describe "#initialize" do
      it "raises an exception" do
        expect { described_class.new }.to raise_error ArgumentError
      end
    end
  end
end
