require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/blk_device_edit_button"

RSpec.shared_examples "edit device" do
  context "and the device is a partition" do
    let(:scenario) { "mixed_disks.yml" }
    let(:device_name) { "/dev/sda1" }
    include_examples "run edit action"
  end

  context "and the device is a Software RAID" do
    let(:scenario) { "md_raid.xml" }
    let(:device_name) { "/dev/md/md0" }
    include_examples "run edit action"
  end

  context "and the device is a disk" do
    let(:scenario) { "mixed_disks.yml" }
    let(:device_name) { "/dev/sda" }
    include_examples "go to device page"
  end

  context "and the device is a dasd" do
    let(:scenario) { "dasd_50GiB.yml" }
    let(:device_name) { "/dev/sda" }
    include_examples "go to device page"
  end

  context "and the device is a multipath" do
    let(:scenario) { "empty-dasd-and-multipath.xml" }
    let(:device_name) { "/dev/mapper/36005076305ffc73a00000000000013b4" }
    include_examples "go to device page"
  end

  context "and the device is a DM RAID" do
    let(:scenario) { "empty-dm_raids.xml" }
    let(:device_name) { "/dev/mapper/isw_ddgdcbibhd_test1" }
    include_examples "go to device page"
  end

  context "and the device is a BIOS MD RAID" do
    let(:scenario) { "md-imsm1-devicegraph.xml" }
    let(:device_name) { "/dev/md/b" }
    include_examples "go to device page"
  end
end

RSpec.shared_examples "run edit action" do
  before do
    allow(Y2Partitioner::Actions::EditBlkDevice).to receive(:new).and_return action
  end

  let(:action) { instance_double(Y2Partitioner::Actions::EditBlkDevice, run: :finish) }

  it "opens the edit workflow for the device" do
    expect(Y2Partitioner::Actions::EditBlkDevice).to receive(:new).with(device)
    button.handle
  end

  it "returns :redraw if the workflow returns :finish" do
    allow(action).to receive(:run).and_return :finish
    expect(button.handle).to eq :redraw
  end

  it "returns nil if the workflow does not return :finish" do
    allow(action).to receive(:run).and_return :back
    expect(button.handle).to be_nil
  end
end

RSpec.shared_examples "go to device page" do
  before do
    allow(pager).to receive(:device_page).with(device).and_return(page)
  end

  let(:pager) { instance_double(Y2Partitioner::Widgets::OverviewTreePager) }

  let(:page) { double("page", label: "disk_page") }

  it "jumps to the disk page" do
    expect(Y2Partitioner::UIState.instance).to receive(:go_to_tree_node).with(page)
    button.handle
  end

  it "returns :redraw" do
    expect(button.handle).to eq :redraw
  end
end

describe Y2Partitioner::Widgets::BlkDeviceEditButton do
  before do
    devicegraph_stub(scenario)
  end

  let(:device) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, device_name) }

  let(:table) { nil }

  let(:pager) { nil }

  let(:scenario) { "mixed_disks.yml" }

  let(:device_name) { "/dev/sda1" }

  include_examples "CWM::PushButton"

  describe "#handle" do
    context "when defined for a specific device" do
      subject(:button) { described_class.new(device: device, pager: pager) }

      include_examples "edit device"
    end

    context "when defined for a table" do
      subject(:button) { described_class.new(table: table, pager: pager) }

      let(:table) { double("table", selected_device: selected_device) }

      context "when no device is selected in the table" do
        let(:selected_device) { nil }

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
        let(:device_name) { "/dev/sda1" }

        let(:selected_device) { device }

        include_examples "edit device"
      end
    end
  end
end
