require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::System do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new("hostname", pager) }

  let(:pager) { double("OverviewTreePager") }

  let(:scenario) { "mixed_disks.yml" }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    let(:table) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDevicesTable) } }

    let(:items) { table.items.map { |i| i[1] } }

    context "when there are disks" do
      let(:scenario) { "mixed_disks.yml" }

      it "contains all disks and their partitions" do
        expect(items).to contain_exactly(
          "/dev/sda",
          "/dev/sda1",
          "/dev/sda2",
          "/dev/sdb",
          "/dev/sdb1",
          "/dev/sdb2",
          "/dev/sdb3",
          "/dev/sdb4",
          "/dev/sdb5",
          "/dev/sdb6",
          "/dev/sdb7",
          "/dev/sdc"
        )
      end
    end

    context "when there are DASDs devices" do
      let(:scenario) { "dasd_50GiB.yml" }

      it "contains all DASDs and their partitions" do
        expect(items).to contain_exactly(
          "/dev/sda",
          "/dev/sda1"
        )
      end
    end

    context "when there are DM RAIDs" do
      let(:scenario) { "empty-dm_raids.xml" }

      it "contains all DM RAIDs" do
        expect(items).to include(
          "/dev/mapper/isw_ddgdcbibhd_test1",
          "/dev/mapper/isw_ddgdcbibhd_test2"
        )
      end

      it "does not contain devices belonging to DM RAIDs" do
        expect(items).to_not include(
          "/dev/sdb",
          "/dev/sdc"
        )
      end

      it "contains devices that does not belong to DM RAIDs" do
        expect(items).to include(
          "/dev/sda",
          "/dev/sda1",
          "/dev/sda2"
        )
      end
    end

    context "when there are BIOS MD RAIDs" do
      let(:scenario) { "md-imsm1-devicegraph.xml" }

      it "contains all BIOS MD RAIDs" do
        expect(items).to include(
          "/dev/md/a",
          "/dev/md/b"
        )
      end

      it "does not contain devices belonging to BIOS DM RAIDs" do
        expect(items).to_not include(
          "/dev/sdb",
          "/dev/sdc",
          "/dev/sdd"
        )
      end

      it "contains devices that does not belong to BIOS DM RAIDs" do
        expect(items).to include(
          "/dev/sda",
          "/dev/sda1",
          "/dev/sda2"
        )
      end
    end

    context "when there are Software RAIDs" do
      let(:scenario) { "md_raid.xml" }

      before do
        Y2Storage::Md.create(current_graph, "/dev/md1")
      end

      it "contains all Software RAIDs" do
        expect(items).to include(
          "/dev/md/md0",
          "/dev/md1"
        )
      end

      it "contains devices belonging to Software RAIDs" do
        expect(items).to include(
          "/dev/sda"
        )
      end
    end

    context "when there are Volume Groups and their logical volumes" do
      let(:scenario) { "lvm-two-vgs.yml" }

      it "contains all Volume Groups" do
        expect(items).to include(
          "/dev/vg0",
          "/dev/vg0/lv1",
          "/dev/vg0/lv2",
          "/dev/vg1",
          "/dev/vg1/lv1"
        )
      end

      it "contains devices belonging to Volume Groups" do
        expect(items).to include(
          "/dev/sda5",
          "/dev/sda7",
          "/dev/sda9"
        )
      end
    end
  end
end
