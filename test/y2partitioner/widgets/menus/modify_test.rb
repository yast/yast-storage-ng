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
require_relative "examples"
require_relative "matchers"

require "y2partitioner/widgets/menus/modify"

describe Y2Partitioner::Widgets::Menus::Modify do
  before do
    devicegraph_stub(scenario)
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:device) { current_graph.find_by_name(device_name) }

  subject { described_class.new(device) }

  let(:scenario) { "one-empty-disk.yml" }

  let(:device_name) { "/dev/sda" }

  include_examples "Y2Partitioner::Widgets::Menus"

  describe "#items" do
    it "includes 'Edit'" do
      expect(subject.items).to include(item_with_id(:menu_edit))
    end

    it "includes 'Show Details'" do
      expect(subject.items).to include(item_with_id(:menu_description))
    end

    it "includes 'Delete'" do
      expect(subject.items).to include(item_with_id(:menu_delete))
    end

    it "includes 'Resize'" do
      expect(subject.items).to include(item_with_id(:menu_resize))
    end

    it "includes 'Move'" do
      expect(subject.items).to include(item_with_id(:menu_move))
    end

    it "includes 'Change Used Devices'" do
      expect(subject.items).to include(item_with_id(:menu_change_devs))
    end

    it "includes 'Create Partition Table'" do
      expect(subject.items).to include(item_with_id(:menu_create_ptable))
    end

    it "includes 'Clone Partitions'" do
      expect(subject.items).to include(item_with_id(:menu_clone_ptable))
    end
  end

  describe "#disabled_items" do
    context "when the device is a disk device (Hard Disk, BIOS RAID, Multipath, DASD)" do
      let(:scenario) { "one-empty-disk.yml" }

      let(:device_name) { "/dev/sda" }

      it "contains 'Delete', 'Resize', 'Move' and 'Change Used Devices'" do
        items = [:menu_delete, :menu_resize, :menu_move, :menu_change_devs]
        expect(subject.disabled_items).to contain_exactly(*items)
      end
    end

    context "when the device is a partition" do
      let(:scenario) { "mixed_disks.yml" }

      let(:device_name) { "/dev/sda1" }

      it "contains 'Change Used Devices', 'Create Partition Table' and 'Clone Partitions'" do
        items = [:menu_change_devs, :menu_create_ptable, :menu_clone_ptable]
        expect(subject.disabled_items).to contain_exactly(*items)
      end
    end

    context "when the device is a MD RAID" do
      let(:scenario) { "md_raid.yml" }

      let(:device_name) { "/dev/md/md0" }

      it "contains 'Resize', 'Move' and 'Clone Partitions'" do
        items = [:menu_resize, :menu_move, :menu_clone_ptable]
        expect(subject.disabled_items).to contain_exactly(*items)
      end
    end

    context "when the device is a LVM Volume Group" do
      let(:scenario) { "trivial_lvm.yml" }

      let(:device_name) { "/dev/vg0" }

      it "contains 'Edit', 'Resize', 'Move', 'Create Partition Table' and 'Clone Partitions'" do
        items = [:menu_edit, :menu_resize, :menu_move, :menu_create_ptable, :menu_clone_ptable]
        expect(subject.disabled_items).to contain_exactly(*items)
      end
    end

    context "when the device is a LVM Logical Volume" do
      let(:scenario) { "trivial_lvm.yml" }

      let(:device_name) { "/dev/vg0/lv1" }

      it "contains 'Move', 'Change Used Devies', 'Create Partition Table' and 'Clone Partitions'" do
        items = [:menu_move, :menu_change_devs, :menu_create_ptable, :menu_clone_ptable]
        expect(subject.disabled_items).to contain_exactly(*items)
      end
    end

    context "when the device is a Bcache" do
      let(:scenario) { "bcache1.xml" }

      let(:device_name) { "/dev/bcache0" }

      it "contains Resize', 'Move' and 'Clone Partitions'" do
        items = [:menu_resize, :menu_move, :menu_clone_ptable]
        expect(subject.disabled_items).to contain_exactly(*items)
      end
    end

    context "when the device is a Btrfs" do
      let(:scenario) { "trivial_btrfs.yml" }

      let(:device_name) { "/dev/sda1" }

      subject { described_class.new(device.blk_filesystem) }

      it "contains 'Resize', 'Move', 'Create Partition Table' and 'Clone Partitions'" do
        items = [:menu_resize, :menu_move, :menu_create_ptable, :menu_clone_ptable]
        expect(subject.disabled_items).to contain_exactly(*items)
      end
    end
  end

  describe "#handle" do
    shared_examples "no action" do |scenario, device_name|
      context "and another type of device is selected" do
        let(:scenario) { scenario }

        let(:device_name) { device_name }

        it "calls no action" do
          expect(Y2Partitioner::Actions::Base).to_not receive(:new)

          subject.handle(event)
        end
      end
    end

    context "when 'Edit' is selected" do
      let(:event) { :menu_edit }

      context "and the selected device can be used as block device" do
        let(:scenario) { "mixed_disks.yml" }

        let(:device_name) { "/dev/sda1" }

        it "calls an action to edit the block device" do
          expect(Y2Partitioner::Actions::EditBlkDevice).to receive(:new).with(device)

          subject.handle(event)
        end
      end

      context "and the selected device is a Btrfs" do
        let(:scenario) { "trivial_btrfs.yml" }

        let(:device_name) { "/dev/sda1" }

        let(:btrfs) { device.blk_filesystem }

        subject { described_class.new(btrfs) }

        it "calls an action to edit the Btrfs" do
          expect(Y2Partitioner::Actions::EditBtrfs).to receive(:new).with(btrfs)

          subject.handle(event)
        end
      end

      include_examples "no action", "trivial_lvm.yml", "/dev/vg0"
    end

    context "when 'Delete' is selected" do
      let(:event) { :menu_delete }

      context "and the selected device is a partition" do
        let(:scenario) { "mixed_disks.yml" }

        let(:device_name) { "/dev/sda1" }

        it "calls an action to delete the partition" do
          expect(Y2Partitioner::Actions::DeletePartition).to receive(:new).with(device)

          subject.handle(event)
        end
      end

      context "and the selected device is a MD RAID" do
        let(:scenario) { "md_raid.yml" }

        let(:device_name) { "/dev/md/md0" }

        it "calls an action to delete the MD RAID" do
          expect(Y2Partitioner::Actions::DeleteMd).to receive(:new).with(device)

          subject.handle(event)
        end
      end

      context "and the selected device is a LVM Volume Group" do
        let(:scenario) { "trivial_lvm.yml" }

        let(:device_name) { "/dev/vg0" }

        it "calls an action to delete the Volume Group" do
          expect(Y2Partitioner::Actions::DeleteLvmVg).to receive(:new).with(device)

          subject.handle(event)
        end
      end

      context "and the selected device is a LVM Logical Volume" do
        let(:scenario) { "trivial_lvm.yml" }

        let(:device_name) { "/dev/vg0/lv1" }

        it "calls an action to delete the Logical Volume" do
          expect(Y2Partitioner::Actions::DeleteLvmLv).to receive(:new).with(device)

          subject.handle(event)
        end
      end

      context "and the selected device is a Bcache" do
        let(:scenario) { "bcache1.xml" }

        let(:device_name) { "/dev/bcache0" }

        it "calls an action to delete the Bcache" do
          expect(Y2Partitioner::Actions::DeleteBcache).to receive(:new).with(device)

          subject.handle(event)
        end
      end

      context "and the selected device is a Btrfs" do
        let(:scenario) { "trivial_btrfs.yml" }

        let(:device_name) { "/dev/sda1" }

        let(:btrfs) { device.blk_filesystem }

        subject { described_class.new(btrfs) }

        it "calls an action to delete the Btrfs" do
          expect(Y2Partitioner::Actions::DeleteBtrfs).to receive(:new).with(btrfs)

          subject.handle(event)
        end
      end

      include_examples "no action", "mixed_disks.yml", "/dev/sda"
    end

    context "when 'Resize' is selected" do
      let(:event) { :menu_resize }

      context "and the selected device is a partition" do
        let(:scenario) { "mixed_disks.yml" }

        let(:device_name) { "/dev/sda1" }

        it "calls an action to resize the partition" do
          expect(Y2Partitioner::Actions::ResizeBlkDevice).to receive(:new).with(device)

          subject.handle(event)
        end
      end

      context "and the selected device is a LVM Logical Volume" do
        let(:scenario) { "trivial_lvm.yml" }

        let(:device_name) { "/dev/vg0/lv1" }

        it "calls an action to resize the Logical Volume" do
          expect(Y2Partitioner::Actions::ResizeBlkDevice).to receive(:new).with(device)

          subject.handle(event)
        end
      end

      include_examples "no action", "mixed_disks.yml", "/dev/sda"
    end

    context "when 'Move' is selected" do
      let(:event) { :menu_move }

      context "and the selected device is a partition" do
        let(:scenario) { "mixed_disks.yml" }

        let(:device_name) { "/dev/sda1" }

        it "calls an action to move the partition" do
          expect(Y2Partitioner::Actions::MovePartition).to receive(:new).with(device)

          subject.handle(event)
        end
      end

      include_examples "no action", "mixed_disks.yml", "/dev/sda"
    end

    context "when 'Change Used Devices' is selected" do
      let(:event) { :menu_change_devs }

      context "and the selected device is a MD RAID" do
        let(:scenario) { "md_raid.yml" }

        let(:device_name) { "/dev/md/md0" }

        it "calls an action to change the devices used by the MD RAID" do
          expect(Y2Partitioner::Actions::EditMdDevices).to receive(:new).with(device)

          subject.handle(event)
        end
      end

      context "and the selected device is a LVM Volume Group" do
        let(:scenario) { "trivial_lvm.yml" }

        let(:device_name) { "/dev/vg0" }

        it "calls an action to change the devices used by the Volume Group" do
          expect(Y2Partitioner::Actions::ResizeLvmVg).to receive(:new).with(device)

          subject.handle(event)
        end
      end

      context "and the selected device is a Btrfs" do
        let(:scenario) { "trivial_btrfs.yml" }

        let(:device_name) { "/dev/sda1" }

        let(:btrfs) { device.blk_filesystem }

        subject { described_class.new(btrfs) }

        it "calls an action to change the devices used by the Btrfs" do
          expect(Y2Partitioner::Actions::EditBtrfsDevices).to receive(:new).with(btrfs)

          subject.handle(event)
        end
      end

      context "and the selected device is a Bcache" do
        let(:scenario) { "bcache1.xml" }

        let(:device_name) { "/dev/bcache0" }

        it "calls an action to change the devices used by the Bcache" do
          expect(Y2Partitioner::Actions::EditBcache).to receive(:new).with(device)

          subject.handle(event)
        end
      end

      include_examples "no action", "mixed_disks.yml", "/dev/sda"
    end

    context "when 'Create Partition Table' is selected" do
      let(:event) { :menu_create_ptable }

      context "and the selected device can be partitioned" do
        let(:scenario) { "mixed_disks.yml" }

        let(:device_name) { "/dev/sda" }

        it "calls an action to create a new partition table" do
          expect(Y2Partitioner::Actions::CreatePartitionTable).to receive(:new).with(device)

          subject.handle(event)
        end
      end

      include_examples "no action", "mixed_disks.yml", "/dev/sda1"
    end

    context "when 'Clone Partitions' is selected" do
      let(:event) { :menu_clone_ptable }

      context "and the selected device is a disk device (Hard Disk, BIOS RAID, Multipath, DASD)" do
        let(:scenario) { "mixed_disks.yml" }

        let(:device_name) { "/dev/sda" }

        it "calls an action to clone the partitions" do
          expect(Y2Partitioner::Actions::ClonePartitionTable).to receive(:new).with(device)

          subject.handle(event)
        end
      end

      include_examples "no action", "mixed_disks.yml", "/dev/sda1"
    end

    context "when 'Show Details' is selected" do
      let(:event) { :menu_description }

      it "opens a dialog with the description of the device" do
        expect(Y2Partitioner::Dialogs::DeviceDescription).to receive(:new).with(device)

        subject.handle(event)
      end
    end
  end
end
