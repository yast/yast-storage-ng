#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

require "yast"
require "cwm/rspec"
require "y2storage"
require "y2partitioner/dialogs/blk_device_resize"
require "y2partitioner/actions/controllers/blk_device"

describe Y2Partitioner::Dialogs::BlkDeviceResize do
  using Y2Storage::Refinements::SizeCasts

  before do
    devicegraph_stub(scenario)

    allow(partition).to receive(:detect_resize_info).and_return resize_info
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:scenario) { "mixed_disks" }

  # Creates a new partition
  let(:partition) do
    sdc = Y2Storage::Disk.find_by_name(current_graph, "/dev/sdc")
    if sdc
      sdc.partition_table.create_partition("/dev/sdc1", Y2Storage::Region.create(2048, 1048576, 512),
        Y2Storage::PartitionType::PRIMARY)
    else
      # DASD case, just take the first partition. That should be enough for these tests
      current_graph.partitions.first
    end
  end

  let(:resize_info) do
    instance_double(Y2Storage::ResizeInfo,
      resize_ok?:   true,
      min_size:     10.MiB,
      max_size:     100.GiB,
      reasons:      0,
      reason_texts: ["Unspecified"])
  end

  subject { described_class.new(controller) }

  let(:controller) { Y2Partitioner::Actions::Controllers::BlkDevice.new(device) }

  let(:device) { partition }

  include_examples "CWM::Dialog"

  describe "#contents" do
    def find_label(contents, text)
      contents.nested_find do |widget|
        widget.respond_to?(:value) &&
          widget.value == :Label &&
          widget.params.any? { |i| i.include?(text) }
      end
    end

    it "contains a widget for selecting the new size" do
      widget = subject.contents.nested_find do |w|
        w.is_a?(Y2Partitioner::Dialogs::BlkDeviceResize::SizeSelector)
      end
      expect(widget).to_not be_nil
    end

    it "shows the current size" do
      label = find_label(subject.contents, "Current size")
      expect(label).to_not be_nil
    end

    context "when the partition does not exist on disk" do
      it "does not show the used size" do
        label = find_label(subject.contents, "Currently used")
        expect(label).to be_nil
      end
    end

    context "when the partition exists on disk" do
      let(:partition) { Y2Storage::Partition.find_by_name(current_graph, "/dev/sda2") }

      context "and it is not formatted" do
        before do
          allow(partition).to receive(:filesystem).and_return(nil)
        end

        it "does not show the used size" do
          label = find_label(subject.contents, "Currently used")
          expect(label).to be_nil
        end
      end

      context "and it is a swap partition" do
        before do
          allow(partition).to receive(:id).and_return(Y2Storage::PartitionId::SWAP)
        end

        it "does not show the used size" do
          label = find_label(subject.contents, "Currently used")
          expect(label).to be_nil
        end
      end

      context "and it is formatted and it is not swap" do
        before do
          allow(partition).to receive(:filesystem).and_return(filesystem)
        end

        let(:ext3) { Y2Storage::Filesystems::Type::EXT3 }
        let(:filesystem) { instance_double("Filesystem", detect_space_info: space_info, type: ext3) }
        let(:space_info) { instance_double(Y2Storage::SpaceInfo, used: 10.GiB) }

        it "shows the used size" do
          label = find_label(subject.contents, "Currently used")
          expect(label).to_not be_nil
        end
      end
    end
  end

  describe "#next_handler" do
    let(:device) { current_graph.find_by_name(device_name) }

    let(:device_name) { "/dev/sda2" }

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

    shared_examples "do not unmount" do
      it "does not ask for unmounting the device" do
        expect(Yast2::Popup).to_not receive(:show).with(/try to unmount/, anything)

        subject.next_handler
      end

      it "returns true" do
        expect(subject.next_handler).to eq(true)
      end
    end

    context "when the device does not exist in the system" do
      before do
        create_partition("/dev/sdc")
      end

      let(:device_name) { "/dev/sdc1" }

      include_examples "do not unmount"
    end

    context "when the device exists in the system" do
      before do
        allow(device).to receive(:detect_resize_info).and_return resize_info
      end

      let(:ext3) { Y2Storage::Filesystems::Type::EXT3 }
      let(:filesystem) { instance_double("Filesystem", detect_space_info: space_info, type: ext3) }
      let(:space_info) { instance_double(Y2Storage::SpaceInfo, used: 10.GiB) }

      context "and it is not formatted in the system" do
        let(:device_name) { "/dev/sdb7" }

        before do
          allow(device).to receive(:filesystem).and_return(filesystem)
        end

        include_examples "do not unmount"
      end

      context "and it is formatted in the system" do
        let(:device_name) { "/dev/sdb2" }

        context "but the current filesystem does not match to the existing filesystem" do
          before do
            allow(device).to receive(:filesystem).and_return(filesystem)
            allow(filesystem).to receive(:sid).and_return(-1)
          end

          include_examples "do not unmount"
        end

        context "and the current filesystem matches to the existing filesystem" do
          before do
            system_devicegraph = Y2Storage::StorageManager.instance.system
            part = system_devicegraph.find_by_name(device_name)
            part.mount_point.active = mounted
          end

          context "but it is not mounted in the system" do
            let(:mounted) { false }

            include_examples "do not unmount"
          end

          context "and it is mounted in the system" do
            let(:mounted) { true }

            before do
              allow_any_instance_of(Y2Storage::Filesystems::BlkFilesystem)
                .to receive(:supports_mounted_shrink?).and_return(mounted_shrink)

              allow_any_instance_of(Y2Storage::Filesystems::BlkFilesystem)
                .to receive(:supports_mounted_grow?).and_return(mounted_grow)

              allow(subject).to receive(:size_selector).and_return(size_selector)
            end

            let(:mounted_shrink) { true }

            let(:mounted_grow) { true }

            let(:size_selector) do
              instance_double(Y2Partitioner::Dialogs::BlkDeviceResize::SizeSelector,
                current_widget: size_widget)
            end

            let(:size_widget) { double("size widget", size: selected_size) }

            shared_examples "do unmount" do
              before do
                allow(Yast2::Popup).to receive(:show).with(/try to unmount/, anything)
                  .and_return(*unmount_answer)
              end

              let(:unmount_answer) { [:cancel] }

              it "asks for unmounting the device" do
                expect(Yast2::Popup).to receive(:show).with(/try to unmount/, anything)

                subject.next_handler
              end

              context "and the user decides to cancel" do
                let(:unmount_answer) { [:cancel] }

                it "returns false" do
                  expect(subject.next_handler).to eq(false)
                end
              end

              context "and the user decides to continue" do
                let(:unmount_answer) { [:continue] }

                it "returns true" do
                  expect(subject.next_handler).to eq(true)
                end
              end

              context "and the user decides to unmount" do
                let(:unmount_answer) { [:unmount, :cancel] }

                context "and the partition can not be unmounted" do
                  before do
                    allow_any_instance_of(Y2Storage::MountPoint).to receive(:immediate_deactivate)
                      .and_raise(Storage::Exception, "fail to unmount")
                  end

                  it "shows an error message" do
                    expect(Yast2::Popup).to receive(:show).with(/could not be unmounted/, anything)

                    subject.next_handler
                  end

                  it "asks for trying to unmount again" do
                    expect(Yast2::Popup).to receive(:show).with(/could not be unmounted/, anything)
                    expect(Yast2::Popup).to receive(:show).with(/try to unmount/, anything).twice

                    subject.next_handler
                  end
                end

                context "and the partition can be unmounted" do
                  before do
                    allow_any_instance_of(Y2Storage::MountPoint).to receive(:immediate_deactivate)
                  end

                  it "returns true" do
                    expect(subject.next_handler).to eq(true)
                  end
                end
              end
            end

            context "and the device is going to be shrinked" do
              let(:selected_size) { 30.GiB } # current size is 60 GiB

              context "and the device supports to shrink being mounted" do
                let(:mounted_shrink) { true }

                include_examples "do not unmount"
              end

              context "and the device does not support to shrink being mounted" do
                let(:mounted_shrink) { false }

                it "shows a specific note for shrinking the device" do
                  expect(Yast2::Popup).to receive(:show)
                    .with(/not possible to shrink/, anything)

                  subject.next_handler
                end

                include_examples "do unmount"
              end
            end

            context "and the device is going to be extended" do
              let(:selected_size) { 65.GiB } # current size is 60 GiB

              context "and the device supports to extend being mounted" do
                let(:mounted_grow) { true }

                context "and the device is going to be extended less than 50 GiB" do
                  include_examples "do not unmount"
                end

                context "and the device is going to be extended more than 50 GiB" do
                  let(:selected_size) { 150.GiB } # current size is 60 GiB

                  it "shows a specific note for extending the device too much" do
                    expect(Yast2::Popup).to receive(:show)
                      .with(/may be quite slow/, anything)

                    subject.next_handler
                  end

                  include_examples "do unmount"
                end
              end

              context "and the device does not support to extend being mounted" do
                let(:mounted_grow) { false }

                it "shows a specific note for extending the device" do
                  expect(Yast2::Popup).to receive(:show)
                    .with(/not possible to extend/, anything)

                  subject.next_handler
                end

                include_examples "do unmount"
              end
            end
          end
        end
      end
    end
  end

  describe Y2Partitioner::Dialogs::BlkDeviceResize::SizeSelector do
    subject(:widget) { described_class.new(device) }

    let(:device) { partition }

    before do
      allow(device).to receive(:detect_resize_info).and_return resize_info
      allow(subject).to receive(:current_widget).and_return(current_widget)
    end

    let(:max_size_widget) { subject.widgets[0] }

    let(:min_size_widget) { subject.widgets[1] }

    let(:custom_size_widget) { subject.widgets[2] }

    let(:max_size) { 100.GiB }

    let(:min_size) { 10.MiB }

    let(:resize_info) do
      instance_double(Y2Storage::ResizeInfo,
        resize_ok?:   true,
        min_size:     min_size,
        max_size:     max_size,
        reasons:      0,
        reason_texts: ["Unspecified"])
    end

    let(:current_widget) { max_size_widget }

    include_examples "CWM::AbstractWidget"

    describe "#store" do
      context "when max size is selected" do
        let(:current_widget) { max_size_widget }

        RSpec.shared_examples "max sizes" do
          context "and the max size causes an end-aligned partition" do
            let(:max_size) { aligned_max_size }

            it "updates the partition with the max size" do
              subject.store
              expect(device.size).to eq max_size
              expect(device.end_aligned?).to eq(true)
            end
          end

          context "and the max size causes a not end-aligned partition" do
            let(:max_size) { not_aligned_max_size }

            it "updates the partition with the max size" do
              subject.store
              expect(device.size).to eq max_size
              expect(device.end_aligned?).to eq(false)
            end
          end
        end

        context "when the partition table does not require end-alignment" do
          let(:scenario) { "mixed_disks" }

          let(:aligned_max_size) { 100.GiB }

          let(:not_aligned_max_size) { 100.GiB + 0.5.MiB }
          let(:adjusted_size) { 100.GiB }

          include_examples "max sizes"
        end

        context "when the partition table requires end-alignment (DASD)" do
          let(:scenario) { "dasd_50GiB.yml" }

          let(:aligned_max_size) { 204864.KiB }

          let(:not_aligned_max_size) { 200.MiB }
          let(:adjusted_size) { 204768.KiB }

          include_examples "max sizes"
        end
      end

      context "when min size is selected" do
        let(:current_widget) { min_size_widget }

        RSpec.shared_examples "min sizes" do
          context "and the min size causes an end-aligned partition" do
            let(:min_size) { aligned_min_size }

            it "updates the partition with the min size" do
              subject.store
              expect(device.size).to eq min_size
              expect(device.end_aligned?).to eq(true)
            end
          end

          context "and the min size causes a not end-aligned partition" do
            let(:min_size) { not_aligned_min_size }

            it "updates the partition with the min aligned size" do
              subject.store
              expect(device.size).to eq adjusted_size
              expect(device.end_aligned?).to eq(true)
              expect(device.size).to be >= min_size
            end
          end
        end

        context "when the partition table does not require end-alignment" do
          let(:scenario) { "mixed_disks" }

          let(:aligned_min_size) { 10.MiB }

          let(:not_aligned_min_size) { 10.4.MiB }
          let(:adjusted_size) { 11.MiB }

          include_examples "min sizes"
        end

        context "when the partition table requires end-alignment (DASD)" do
          let(:scenario) { "dasd_50GiB.yml" }

          let(:aligned_min_size) { 24768.KiB }

          let(:not_aligned_min_size) { 12344.KiB }
          let(:adjusted_size) { 12384.KiB }

          include_examples "min sizes"
        end
      end

      context "when custom size is selected" do
        let(:current_widget) { custom_size_widget }

        before do
          allow(current_widget).to receive(:size).and_return(custom_size)
        end

        RSpec.shared_examples "custom sizes" do
          context "and the entered size causes an end-aligned partition" do
            let(:custom_size) { aligned_size }

            it "updates the partition with the entered size" do
              subject.store
              expect(device.size).to eq aligned_size
              expect(device.end_aligned?).to eq(true)
            end
          end

          context "and the entered size causes a not end-aligned partition" do
            let(:custom_size) { not_aligned_size }

            it "updates the partition with the closest valid aligned size" do
              subject.store
              expect(device.size).to eq adjusted_size
              expect(device.end_aligned?).to eq(true)
              expect(adjusted_size).to be <= max_size
              expect(adjusted_size).to be >= min_size
            end
          end
        end

        context "when the partition table does not require end-alignment" do
          let(:scenario) { "mixed_disks" }

          let(:aligned_size) { 50.GiB }

          let(:not_aligned_size) { 50.GiB + 0.5.MiB }
          let(:adjusted_size) { 50.GiB }

          include_examples "custom sizes"
        end

        context "when the device table requires end-alignment (DASD)" do
          let(:scenario) { "dasd_50GiB.yml" }

          let(:aligned_size) { 204864.KiB }

          let(:not_aligned_size) { 200.MiB }
          let(:adjusted_size) { 204768.KiB }

          include_examples "custom sizes"
        end
      end

      context "when the device is an LVM thin pool" do
        let(:scenario) { "lvm-two-vgs.yml" }

        let(:device) do
          # Create a thin pool
          vg = Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg1")
          vg.create_lvm_lv("pool", Y2Storage::LvType::THIN_POOL, 1.GiB)
        end

        before do
          allow(current_widget).to receive(:size).and_return(custom_size)

          # Create a thin volume over the pool
          device.create_lvm_lv("thin", Y2Storage::LvType::THIN, thin_size)
        end

        let(:current_widget) { custom_size_widget }

        context "and it is overcommitted after resizing" do
          let(:thin_size) { 2.GiB }

          let(:custom_size) { 1.GiB }

          it "shows a warning message" do
            expect(Yast2::Popup).to receive(:show)
            subject.store
          end
        end

        context "and it is not overcommitted after resizing" do
          let(:thin_size) { 2.GiB }

          let(:custom_size) { 3.GiB }

          it "does not show a warning message" do
            expect(Yast2::Popup).to_not receive(:show)
            subject.store
          end
        end
      end

      context "when the device is not an LVM thin pool" do
        let(:scenario) { "lvm-two-vgs.yml" }

        let(:device) { Y2Storage::BlkDevice.find_by_name(current_graph, "/dev/vg1/lv1") }

        before do
          allow(current_widget).to receive(:size).and_return(custom_size)
        end

        let(:current_widget) { custom_size_widget }

        let(:custom_size) { 3.GiB }

        it "does not show a warning message" do
          expect(Yast2::Popup).to_not receive(:show)
          subject.store
        end
      end
    end

    describe "#validate" do
      let(:current_widget) { custom_size_widget }

      before do
        allow(current_widget).to receive(:size).and_return(custom_size)
        allow(Yast2::Popup).to receive(:show)
      end

      shared_examples "error" do
        before do
          allow(subject).to receive(:validation_warnings).and_return(["a warning"])
        end

        it "shows an error popup" do
          expect(Yast2::Popup).to receive(:show).with(anything, hash_including(headline: :error))
          subject.validate
        end

        it "does not show a warning popup" do
          expect(Yast2::Popup).to_not receive(:show).with(anything, hash_including(headline: :warning))
          subject.validate
        end

        it "returns false" do
          expect(subject.validate).to eq(false)
        end
      end

      context "when the given value is less than the min possible size" do
        let(:custom_size) { 5.MiB }

        include_examples "error"
      end

      context "when the given value is bigger than the max possible size" do
        let(:custom_size) { 101.GiB }

        include_examples "error"
      end

      context "when the given value is not a valid size" do
        let(:custom_size) { nil }

        include_examples "error"
      end

      context "when the given value is bigger than min and less than max" do
        let(:custom_size) { 10.GiB }

        before do
          allow(subject).to receive(:filesystem_errors).and_return(warnings)
          allow(Yast2::Popup).to receive(:show)
            .with(anything, hash_including(headline: :warning)).and_return(accept)
        end

        let(:accept) { nil }

        context "and there are no warnings" do
          let(:warnings) { [] }

          it "does not show a warning popup" do
            expect(Yast2::Popup).to_not receive(:show)
            subject.validate
          end

          it "returns true" do
            expect(subject.validate).to eq(true)
          end
        end

        context "and there are warnings" do
          let(:warnings) { ["warning1", "warning2"] }

          it "shows a warning popup" do
            expect(Yast2::Popup).to receive(:show).with(anything, hash_including(headline: :warning))
            subject.validate
          end

          context "and the user accepts" do
            let(:accept) { :yes }

            it "returns true" do
              expect(subject.validate).to eq(true)
            end
          end

          context "and the user declines" do
            let(:accept) { :no }

            it "returns false" do
              expect(subject.validate).to eq(false)
            end
          end
        end
      end
    end

    describe "#value" do
      let(:current_widget) { custom_size_widget }

      before do
        allow(Yast::UI).to receive(:QueryWidget).with(Id(current_widget.widget_id), :Value)
          .and_return entered
      end

      context "when a valid size is entered" do
        let(:entered) { "10 GiB" }

        it "returns the corresponding DiskSize object" do
          expect(current_widget.value).to eq 10.GiB
        end
      end

      context "when no units are specified" do
        let(:entered) { "10" }

        it "returns a DiskSize object" do
          expect(current_widget.value).to be_a Y2Storage::DiskSize
        end

        it "considers the units to be bytes" do
          expect(current_widget.value.to_i).to eq 10
        end
      end

      context "when International System units are used" do
        let(:entered) { "10gb" }

        it "considers them as base 2 units" do
          expect(current_widget.value).to eq 10.GiB
        end
      end

      context "when the units are only partially specified" do
        let(:entered) { "10g" }

        it "considers them as base 2 units" do
          expect(current_widget.value).to eq 10.GiB
        end
      end

      context "when nothing is entered" do
        let(:entered) { "" }

        it "returns nil" do
          expect(current_widget.value).to be_nil
        end
      end

      context "when an invalid string is entered" do
        let(:entered) { "a big chunk" }

        it "returns nil" do
          expect(current_widget.value).to be_nil
        end
      end
    end
  end

  describe Y2Partitioner::Dialogs::BlkDeviceResize::FixedSizeWidget do
    subject(:widget) { described_class.new(1.GiB) }

    include_examples "CWM::AbstractWidget"
  end

  describe Y2Partitioner::Dialogs::BlkDeviceResize::CustomSizeWidget do
    subject(:widget) { described_class.new(10.MiB, 100.GiB, 5.GiB) }

    include_examples "CWM::AbstractWidget"
  end
end
