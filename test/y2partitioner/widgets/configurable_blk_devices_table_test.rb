require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/widgets/overview"

describe Y2Partitioner::Widgets::ConfigurableBlkDevicesTable do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(devices, pager) }

  let(:devices) { device_graph.disks }

  let(:pager) { instance_double(Y2Partitioner::Widgets::OverviewTreePager) }

  # FIXME: default tests check that all column headers are strings, but they also can be a Yast::Term
  # include_examples "CWM::Table"

  describe "#header" do
    it "returns array" do
      expect(subject.header).to be_a(::Array)
    end
  end

  describe "#items" do
    let(:devices) { device_graph.partitions }

    it "returns array of arrays" do
      expect(subject.items).to be_a(::Array)
      expect(subject.items.first).to be_a(::Array)
    end

    it "adds asterisk to mount point when not mounted" do
      allow_any_instance_of(Y2Storage::MountPoint).to receive(:active?).and_return(false)

      items = subject.items
      puts items.inspect
      expect(subject.items.any? { |i| i.any? { |inner| inner =~ /\(*\)/ } }).to(
        eq(true), "Missing items with asterisk: #{items.inspect}"
      )
    end
  end

  describe "#init" do
    context "UIState contain sid of device in table" do
      it "sets value to row with the device" do
        valid_sid = devices.last.sid
        Y2Partitioner::UIState.instance.select_row(valid_sid)

        expect(subject).to receive(:value=).with(subject.send(:row_id, valid_sid))

        subject.init
      end
    end

    context "UIState contain sid that is not in table" do
      it "selects any valid device in table" do
        Y2Partitioner::UIState.instance.select_row("999999999")

        expect(subject).to receive(:value=) do |value|
          sid = value[/.*:(.*)/, 1].to_i # c&p from code
          expect(devices.map(&:sid)).to include(sid)
        end

        subject.init
      end
    end

    context "table does not contain any device" do
      let(:devices) { [] }

      it "do nothing" do
        expect(subject).to_not receive(:value=)

        subject.init
      end
    end
  end

  describe "#handle" do
    before do
      allow(subject).to receive(:selected_device).and_return(device)
      allow(pager).to receive(:device_page).with(device).and_return(page)
    end

    let(:device) { nil }

    let(:page) { nil }

    context "when there is no selected device" do
      it "returns nil" do
        expect(subject.handle).to be_nil
      end
    end

    context "when there is no page associated to the selected device" do
      let(:device) { Y2Storage::LvmPv.all(device_graph).first }

      let(:page) { nil }

      it "returns nil" do
        expect(subject.handle).to be_nil
      end
    end

    context "when there is a page associated to the selected device" do
      let(:device) { Y2Storage::Disk.all(device_graph).first }

      let(:page) { instance_double(Y2Partitioner::Widgets::Pages::Disk, widget_id: "disk_page_id") }

      it "goes to the device page" do
        expect(pager).to receive(:handle).with("ID" => "disk_page_id")
        subject.handle
      end
    end
  end

  describe "#selected_device" do
    context "when the table is empty" do
      before do
        allow(subject).to receive(:items).and_return([])
      end

      it "returns nil" do
        expect(subject.selected_device).to be_nil
      end
    end

    context "when the table is not empty" do
      context "and there is no selected row" do
        before do
          allow(subject).to receive(:value).and_return(nil)
        end

        it "returns nil" do
          expect(subject.selected_device).to be_nil
        end
      end

      context "and a row is selected" do
        before do
          allow(subject).to receive(:value).and_return("table:partition:#{selected_device.sid}")
        end

        let(:selected_device) do
          Y2Storage::BlkDevice.find_by_name(device_graph, selected_device_name)
        end

        let(:selected_device_name) { "/dev/sda2" }

        it "returns the selected device" do
          device = subject.selected_device

          expect(device).to eq(selected_device)
        end
      end
    end
  end
end
