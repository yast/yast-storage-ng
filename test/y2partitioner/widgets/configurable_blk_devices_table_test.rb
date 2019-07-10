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
  let(:buttons_set) { instance_double(Y2Partitioner::Widgets::DeviceButtonsSet) }

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
      expect(subject.items.any? { |i| i.any? { |inner| inner =~ / */ } }).to(
        eq(true), "Missing items with asterisk: #{items.inspect}"
      )
    end
  end

  describe "#init" do
    before do
      allow(Yast::UI).to receive(:QueryWidget).with(anything, :SelectedItems).and_return []
    end

    context "if UIState contains the sid of a device in table" do
      let(:device) { devices.last }

      before { Y2Partitioner::UIState.instance.select_row(device.sid) }

      it "sets value to row with the device" do
        expect(subject).to receive(:value=).with(subject.send(:row_id, device.sid))
        subject.init
      end

      context "if the table is associated to a buttons set" do
        subject { described_class.new(devices, pager, buttons_set) }

        it "initializes the buttons set according to the device" do
          expect(subject).to receive(:selected_device).and_return(device)
          expect(buttons_set).to receive(:device=).with device
          subject.init
        end
      end
    end

    context "if UIState contains a sid that is not in the table" do
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
    subject { described_class.new(devices, pager, set) }

    before do
      allow(subject).to receive(:selected_device).and_return(device)
      allow(pager).to receive(:device_page).with(device).and_return(page)
    end

    let(:device) { nil }
    let(:set) { nil }
    let(:page) { nil }

    context "when the event is Activated (double click)" do
      let(:event) { { "EventReason" => "Activated" } }

      context "when there is no selected device" do
        it "returns nil" do
          expect(subject.handle(event)).to be_nil
        end
      end

      context "when there is no page associated to the selected device" do
        let(:device) { Y2Storage::LvmPv.all(device_graph).first }

        let(:page) { nil }

        it "returns nil" do
          expect(subject.handle(event)).to be_nil
        end
      end

      context "when there is a page associated to the selected device" do
        let(:device) { Y2Storage::Disk.all(device_graph).first }

        let(:page) { instance_double(Y2Partitioner::Widgets::Pages::Disk, widget_id: "disk_page_id") }

        it "goes to the device page" do
          expect(pager).to receive(:handle).with("ID" => "disk_page_id")
          subject.handle(event)
        end
      end
    end

    context "when the event is SelectionChanged (single click)" do
      let(:event) { { "EventReason" => "SelectionChanged" } }

      context "when there is a buttons set associated to the table" do
        let(:set) { buttons_set }

        context "and there is no selected device" do
          let(:device) { nil }

          it "does not try to update the buttons set" do
            expect(buttons_set).to_not receive(:device=)
            subject.handle(event)
          end

          it "returns nil" do
            expect(subject.handle(event)).to be_nil
          end
        end

        context "and some device is selected" do
          let(:device) { Y2Storage::Disk.all(device_graph).first }

          it "updates the buttons set according to the device" do
            expect(buttons_set).to receive(:device=).with(device)
            subject.handle(event)
          end

          it "returns nil" do
            allow(buttons_set).to receive(:device=)
            expect(subject.handle(event)).to be_nil
          end
        end
      end

      context "when there is no buttons set associated to the table" do
        context "and there is no selected device" do
          let(:device) { nil }

          it "does not try to update the buttons set" do
            expect(buttons_set).to_not receive(:device=)
            subject.handle(event)
          end

          it "returns nil" do
            expect(subject.handle(event)).to be_nil
          end
        end

        context "and some device is selected" do
          let(:device) { Y2Storage::Disk.all(device_graph).first }

          it "does not try to update the buttons set" do
            expect(buttons_set).to_not receive(:device=)
            subject.handle(event)
          end

          it "returns nil" do
            expect(subject.handle(event)).to be_nil
          end
        end
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
