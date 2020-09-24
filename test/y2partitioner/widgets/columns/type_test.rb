#!/usr/bin/env rspec

# Copyright (c) [2020] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../../test_helper"
require_relative "./shared_examples"

require "y2partitioner/widgets/columns/type"

describe Y2Partitioner::Widgets::Columns::Type do
  subject { described_class.new }

  include_examples "Y2Partitioner::Widgets::Column"

  describe "#values_for" do
    let(:scenario) { "lvm-types1.xml" }
    let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
    let(:blk_device) { devicegraph.find_by_name(device_name) }
    let(:device_name) { "/dev/sda1" }
    let(:device) { blk_device }
    let(:blk_filesystem) { blk_device.blk_filesystem }
    let(:label) { subject.value_for(device).params.find { |param| !param.is_a?(Yast::Term) } }

    before do
      devicegraph_stub(scenario)
    end

    it "returns a Yast::Term" do
      expect(subject.value_for(device)).to be_a(Yast::Term)
    end

    it "includes an icon" do
      value = subject.value_for(device)
      icon = value.params.find { |param| param.is_a?(Yast::Term) && param.value == :icon }

      expect(icon).to_not be_nil
    end

    context "when the device is a filesystem" do
      let(:scenario) { "mixed_disks_btrfs" }
      let(:device_name) { "/dev/sdd1" }
      let(:device) { blk_filesystem }

      it "returns its human readable type" do
        expect(subject.value_for(device)).to include("BtrFS")
      end
    end

    context "when the device is an LVM volume group" do
      let(:device_name) { "/dev/vg0" }

      it "returns 'LVM'" do
        expect(label).to eq("LVM")
      end
    end

    context "when the device is an LVM non-thin snapshot" do
      let(:device_name) { "/dev/vg0/snap_normal1" }

      it "includes the 'Snapshot of'" do
        expect(label).to include("Snapshot of")
      end

      it "includes the origin volume basename" do
        expect(label).to include("normal1")
      end
    end

    context "when the device is an LVM thin snapshot" do
      let(:device_name) { "/dev/vg0/snap_thinvol1" }

      it "includes the 'Thin Snapshot of'" do
        expect(label).to include("Thin Snapshot of")
      end

      it "includes the origin volume basename" do
        expect(label).to include("thinvol1")
      end
    end

    context "when the device is formatted" do
      let(:device_name) { "/dev/vg0/cached1" }

      it "includes the human readable filesystem type" do
        expect(label).to include("XFS")
      end

      it "includes default device label" do
        expect(label).to include("Cache LV")
      end

      context "but it is the external journal of an Ext3/4 filesystem" do
        let(:scenario) { "bug_1145841.xml" }
        let(:device_name) { "/dev/sdd1" }

        it "includes the human readable filesystem type" do
          expect(label).to include("Ext4")
        end

        it "includes 'Journal'" do
          expect(label).to include("Journal")
        end

        it "includes the data device base name" do
          expect(label).to include("BACKUP_R6")
        end
      end

      context "but it is part of a multi-device filesystem" do
        let(:scenario) { "btrfs2-devicegraph.xml" }
        let(:device_name) { "/dev/sdb1" }

        it "includes 'Part of'" do
          expect(label).to include("Part of")
        end

        it "includes the filesystem name" do
          expect(label).to include("btrfs")
        end

        it "includes the block device basename" do
          expect(label).to include("sdb1")
        end
      end
    end

    context "when the device is not formatted" do
      context "and it is an used LVM physical volume" do
        let(:device_name) { "/dev/sdb1" }
        let(:vg) { device.lvm_pv.lvm_vg }

        context "in a volume group with name" do
          it "includes 'PV of'" do
            expect(label).to include("PV of")
          end

          it "includes the volume group name" do
            expect(label).to include("vg0")
          end
        end

        context "in a volume group with an empty name" do
          before do
            vg.vg_name = ""
          end

          it "returns 'PV of LVM'" do
            expect(label).to eq("PV of LVM")
          end
        end
      end

      context "and it is an unused LVM physical volume" do
        let(:scenario) { "unused_lvm_pvs.xml" }
        let(:device_name) { "/dev/sda2" }

        it "returns 'Unused LVM PV'" do
          expect(label).to eq("Unused LVM PV")
        end
      end

      context "and it is part of an MD RAID" do
        let(:scenario) { "md_raid.yml" }
        let(:device_name) { "/dev/sda2" }

        it "includes 'Part of'" do
          expect(label).to include("Part of")
        end

        it "includes the MD RAID name" do
          expect(label).to include("md0")
        end
      end

      context "and it is part of a bcache" do
        let(:scenario) { "bcache1.xml" }
        let(:device_name) { "/dev/vdc" }

        it "includes 'Backing of'" do
          expect(label).to include("Backing of")
        end

        it "includes the bcache name" do
          expect(label).to include("bcache0")
        end
      end

      context "and it is used as caching device in a bcache" do
        let(:scenario) { "bcache1.xml" }
        let(:device_name) { "/dev/vdb" }

        it "returns 'Bcache cache'" do
          expect(label).to include("Bcache caching")
        end
      end
    end
  end
end
