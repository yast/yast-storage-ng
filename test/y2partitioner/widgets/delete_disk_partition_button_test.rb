require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/delete_disk_partition_button"

describe Y2Partitioner::Widgets::DeleteDiskPartitionButton do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  let(:device) { Y2Storage::BlkDevice.find_by_name(device_graph, device_name) }

  let(:device_name) { "/dev/sda2" }

  let(:table) { double("table", selected_device: device) }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(device: device, table: table, device_graph: device_graph) }

  include_examples "CWM::PushButton"

  describe "#handle" do
    context "when no device is selected" do
      let(:device) { nil }

      before do
        allow(table).to receive(:value).and_return(nil)
      end

      it "shows an error message" do
        expect(Yast::Popup).to receive(:Error)
        subject.handle
      end

      it "does not delete the device" do
        subject.handle
        expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to_not be_nil
      end

      it "returns nil" do
        expect(subject.handle).to be(nil)
      end
    end

    context "when selected device is a disk device" do
      context "and does not have partitions" do
        let(:device_name) { "/dev/sdc" }

        it "shows an error message" do
          expect(Yast::Popup).to receive(:Error)
          subject.handle
        end

        it "does not delete the device" do
          subject.handle
          expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to_not be_nil
        end

        it "returns nil" do
          expect(subject.handle).to be(nil)
        end
      end
    end

    context "when a device is selected" do
      let(:device_name) { "/dev/sda2" }

      before do
        allow(Yast::Popup).to receive(:YesNo).and_return(accept)
      end

      let(:accept) { nil }

      it "shows a confirm message" do
        expect(Yast::Popup).to receive(:YesNo)
        subject.handle
      end

      context "when the confirm message is not accepted" do
        let(:accept) { false }

        it "does not delete the device" do
          subject.handle
          expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to_not be_nil
        end

        it "returns nil" do
          expect(subject.handle).to be_nil
        end
      end

      context "when the confirm message is accepted" do
        let(:accept) { true }

        it "deletes the device" do
          subject.handle
          expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to be_nil
        end

        it "refresh btrfs subvolumes shadowing" do
          expect(Y2Storage::Filesystems::Btrfs).to receive(:refresh_subvolumes_shadowing)
          subject.handle
        end

        it "returns :redraw" do
          expect(subject.handle).to eq(:redraw)
        end
      end
    end
  end
end
