#!/usr/bin/env rspec

# Copyright (c) [2017-2021] SUSE LLC
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

require_relative "../test_helper"
require "y2partitioner/actions/resize_blk_device"
require "y2partitioner/dialogs/blk_device_resize"
require "y2partitioner/device_graphs"

describe Y2Partitioner::Actions::ResizeBlkDevice do
  using Y2Storage::Refinements::SizeCasts

  before do
    devicegraph_stub(scenario)
  end

  subject(:action) { described_class.new(device) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:device) { current_graph.find_by_name(device_name) }

  let(:resize_info) do
    instance_double(Y2Storage::ResizeInfo,
      resize_ok?:   can_resize,
      min_size:     min_size,
      max_size:     max_size,
      reasons:      0,
      reason_texts: ["Unspecified"])
  end
  let(:can_resize) { nil }
  let(:min_size) { 100.KiB }
  let(:max_size) { 1.GiB }

  RSpec.shared_examples "resize_error" do
    before do
      allow(Yast2::Popup).to receive(:show)
    end

    it "shows an error popup" do
      expect(Yast2::Popup).to receive(:show).with(anything, headline: :error)
      action.run
    end

    it "quits returning :back" do
      expect(action.run).to eq :back
    end
  end

  RSpec.shared_examples "partition_holds_lvm" do
    context "and the partition holds an LVM" do
      let(:scenario) { "lvm-two-vgs.yml" }
      let(:device_name) { "/dev/sda7" }

      include_examples "resize_error"
    end
  end

  RSpec.shared_examples "partition_holds_md" do
    context "and the partition holds a MD RAID" do
      let(:scenario) { "md_raid" }
      let(:device_name) { "/dev/sda1" }

      include_examples "resize_error"
    end
  end

  shared_examples "can resize" do
    context "and the user goes forward in the dialog" do
      before do
        allow(Y2Partitioner::Dialogs::BlkDeviceResize).to receive(:run).and_return(:next)
      end

      it "returns :finish" do
        expect(action.run).to eq(:finish)
      end
    end

    context "and the user aborts the process" do
      before do
        allow(Y2Partitioner::Dialogs::BlkDeviceResize).to receive(:run).and_return(:abort)
      end

      it "returns :abort" do
        expect(action.run).to eq(:abort)
      end
    end
  end

  def create_partition(disk_name)
    disk = current_graph.find_by_name(disk_name)
    slot = disk.partition_table.unused_partition_slots.first
    part = disk.partition_table.create_partition(
      slot.name,
      slot.region,
      Y2Storage::PartitionType::PRIMARY
    )
    part.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
  end

  describe "#run" do
    let(:scenario) { "mixed_disks" }

    let(:can_resize) { true }

    shared_examples "do not unmount" do
      it "does not ask for unmounting the device" do
        expect_any_instance_of(Y2Partitioner::Dialogs::Unmount).to_not receive(:run)

        action.run
      end
    end

    context "when the device does not exist in the system" do
      before do
        create_partition("/dev/sdc")

        allow(Y2Partitioner::Dialogs::BlkDeviceResize).to receive(:run).and_return(:abort)
      end

      let(:device_name) { "/dev/sdc1" }

      include_examples "do not unmount"
    end

    context "when the device exists in the system" do
      before do
        allow(Y2Partitioner::Dialogs::BlkDeviceResize).to receive(:run).and_return(:abort)
      end

      context "and it is not currently formatted" do
        let(:device_name) { "/dev/sdb7" }

        before do
          allow(Yast2::Popup).to receive(:show).and_return(:yes)
        end

        include_examples "do not unmount"
      end

      context "and it is currently formatted" do
        context "but it is not formatted in the system" do
          let(:device_name) { "/dev/sdb7" }

          before do
            device.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
          end

          include_examples "do not unmount"
        end

        context "and it is formatted in the system" do
          let(:device_name) { "/dev/sdb2" }

          context "but the current filesystem does not match to the existing filesystem" do
            before do
              device.delete_filesystem
              device.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
            end

            include_examples "do not unmount"
          end

          context "and the current filesystem matches to the existing filesystem" do
            before do
              allow(device).to receive(:detect_resize_info).and_return(resize_info)
            end

            context "but the filesystem type is not NTFS" do
              let(:device_name) { "/dev/sdb2" }

              include_examples "do not unmount"
            end

            context "and the filesystem type is NTFS" do
              let(:device_name) { "/dev/sda1" }

              before do
                system_devicegraph = Y2Storage::StorageManager.instance.system
                part = system_devicegraph.find_by_name(device_name)
                part.filesystem.mount_path = "/foo"
                part.mount_point.active = mounted
              end

              context "but it is not mounted in the system" do
                let(:mounted) { false }

                include_examples "do not unmount"
              end

              context "and it is mounted in the system" do
                let(:mounted) { true }

                before do
                  allow(Y2Partitioner::Dialogs::Unmount).to receive(:new).and_return(unmount_dialog)
                end

                let(:unmount_dialog) { instance_double(Y2Partitioner::Dialogs::Unmount, run: :finish) }

                it "asks for unmounting the device" do
                  expect(Y2Partitioner::Dialogs::Unmount).to receive(:new) do |filesystem, _|
                    expect(filesystem.sid).to eq(device.filesystem.sid)
                  end.and_return(unmount_dialog)

                  subject.run
                end

                it "does not allow to continue without unmounting" do
                  expect(Y2Partitioner::Dialogs::Unmount).to receive(:new) do |_, options|
                    expect(options[:allow_continue]).to eq(false)
                  end.and_return(unmount_dialog)

                  action.run
                end
              end
            end
          end
        end
      end
    end

    context "when executed on a partition" do
      let(:partition) { device }

      before do
        allow(device).to receive(:detect_resize_info).and_return(resize_info)
      end

      context "when the partition cannot be resized" do
        let(:can_resize) { false }

        context "and the partition does not hold an LVM neither a MD RAID" do
          let(:scenario) { "mixed_disks.yml" }
          let(:device_name) { "/dev/sda1" }

          include_examples "resize_error"
        end

        include_examples "partition_holds_lvm"

        include_examples "partition_holds_md"
      end

      context "when the partition can be resized" do
        let(:can_resize) { true }

        context "and the partition is used by a multi-device Btrfs" do
          let(:scenario) { "btrfs2-devicegraph.xml" }

          let(:device_name) { "/dev/sdb1" }

          include_examples "can resize"
        end

        context "and the partition does not hold an LVM neither a MD RAID" do
          let(:scenario) { "mixed_disks.yml" }
          let(:device_name) { "/dev/sda1" }

          include_examples "can resize"
        end

        include_examples "partition_holds_lvm"

        include_examples "partition_holds_md"
      end
    end

    context "when executed on an 'empty' partition" do
      let(:scenario) { "mixed_disks.yml" }

      let(:device_name) { "/dev/sdb7" }

      it "shows a warning popup" do
        expect(Yast2::Popup).to receive(:show)
        action.run
      end
    end

    context "when executed on an LVM logical volume" do
      let(:scenario) { "complex-lvm-encrypt" }

      let(:device_name) { "/dev/vg1/lv1" }

      let(:lv) { device }

      before do
        allow(device).to receive(:detect_resize_info).and_return(resize_info)
      end

      context "when the volume cannot be resized" do
        let(:can_resize) { false }

        include_examples "resize_error"
      end

      context "when the volume can be resized" do
        let(:can_resize) { true }

        include_examples "can resize"

        context "when the volume is used by a multi-device Btrfs" do
          before do
            lv.delete_filesystem
            fs = lv.create_filesystem(Y2Storage::Filesystems::Type::BTRFS)

            lv2 = current_graph.find_by_name("/dev/vg1/lv2")
            lv2.delete_filesystem
            fs.add_device(lv2)
          end

          include_examples "can resize"
        end
      end
    end

    context "when executed on an LVM thin snapashot volume" do
      let(:scenario) { "lvm-types1.xml" }
      let(:device_name) { "/dev/vg0/thin_snap_normal2" }

      before do
        allow(device).to receive(:detect_resize_info).and_return(resize_info)
      end

      it "shows a warning popup" do
        expect(Yast2::Popup).to receive(:show)
          .with(/device is an LVM Thin Snapshot/, hash_including(headline: :warning))

        action.run
      end
    end
  end
end
