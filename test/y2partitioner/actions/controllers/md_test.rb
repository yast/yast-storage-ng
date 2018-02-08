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

require_relative "../../test_helper"
require "y2partitioner/device_graphs"
require "y2partitioner/actions/controllers/md"

describe Y2Partitioner::Actions::Controllers::Md do
  using Y2Storage::Refinements::SizeCasts

  before do
    devicegraph_stub(scenario)
  end

  subject(:controller) { described_class.new }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:scenario) { "complex-lvm-encrypt.yml" }

  def dev(name)
    result = Y2Storage::BlkDevice.find_by_name(current_graph, name)
    result ||= Y2Storage::LvmVg.all(current_graph).find { |i| i.name == name }
    result
  end

  describe "#initialize" do
    context "when no Md device is given" do
      it "creates a new Md device with a valid level" do
        expect(current_graph.md_raids).to be_empty
        described_class.new
        expect(current_graph.md_raids).to_not be_empty
        expect(current_graph.md_raids.first.md_level.is?(:unknown)).to eq(false)
      end
    end

    context "when a Md device is given" do
      let(:scenario) { "md_raid.xml" }

      let(:md) { current_graph.md_raids.first }

      it "does not creates a new Md device" do
        mds = current_graph.md_raids
        described_class.new(md: md)
        expect(current_graph.md_raids).to eq(mds)
      end

      it "uses the given Md device" do
        controller = described_class.new(md: md)
        expect(controller.md).to eq(md)
      end
    end
  end

  describe "#md" do
    it "returns a Y2Storage::Md" do
      expect(controller.md).to be_a(Y2Storage::Md)
    end

    context "when the controller is created without Md device" do
      it "returns the new created Md device" do
        expect(current_graph.md_raids).to be_empty
        md = controller.md
        expect(current_graph.md_raids).to include(md)
      end
    end

    context "when the controller is created with a Md device" do
      let(:scenario) { "md_raid.xml" }

      let(:md) { current_graph.md_raids.first }

      subject(:controller) { described_class.new(md: md) }

      it "returns the given Md device" do
        expect(controller.md).to eq(md)
      end
    end
  end

  describe "#available_devices" do
    it "returns an array of partitions" do
      expect(controller.available_devices).to be_an Array
      expect(controller.available_devices).to all be_a(Y2Storage::Partition)
    end

    it "returns partitions with a linux system ID (linux, LVM, RAID, swap)" do
      devices = controller.available_devices
      expect(devices.map(&:name)).to eq ["/dev/sda2", "/dev/sda3", "/dev/sda4", "/dev/sde3"]
    end

    it "includes partitions with an unmounted filesystem" do
      expect(controller.available_devices.map(&:name)).to include("/dev/sda2", "/dev/sde3")
    end

    it "excludes partitions with a mount point" do
      expect(controller.available_devices.map(&:name)).to include("/dev/sda2", "/dev/sde3")

      sda2 = dev("/dev/sda2")
      sda2.filesystem.mount_path = "/var"
      sde3 = dev("/dev/sde3")
      sde3.filesystem.mount_path = "swap"

      expect(controller.available_devices.map(&:name)).to_not include("/dev/sda2", "/dev/sde3")
    end

    it "excludes partitions that are part of an LVM" do
      expect(controller.available_devices.map(&:name)).to_not include("/dev/sde1", "/dev/sde2")
      sda3 = dev("/dev/sda3")
      expect(controller.available_devices).to include sda3

      vg0 = dev("/dev/vg0")
      vg0.add_lvm_pv(sda3)
      expect(controller.available_devices).to_not include sda3
    end

    it "excludes partitions that are part of another MD Raid" do
      sda3 = dev("/dev/sda3")
      expect(controller.available_devices).to include sda3

      new_md = Y2Storage::Md.create(current_graph, "/dev/md0")
      new_md.add_device(sda3)
      expect(controller.available_devices).to_not include sda3
    end
  end

  describe "#devices_in_md" do
    let(:cr_sda4) { Y2Storage::BlkDevice.find_by_name(current_graph, "/dev/mapper/cr_sda4") }
    let(:sda3) { Y2Storage::BlkDevice.find_by_name(current_graph, "/dev/sda3") }

    before do
      cr_sda4.remove_descendants
      controller.md.push_device(cr_sda4)
      controller.md.push_device(sda3)
    end

    it "returns an array with all the partitions in the Md device" do
      expect(controller.devices_in_md).to be_an Array
      expect(controller.devices_in_md).to all be_a(Y2Storage::Partition)
      expect(controller.devices_in_md.size).to eq 2
    end

    it "returns a list sorted by the position of the devices in the RAID" do
      expect(controller.devices_in_md.map(&:name)).to eq ["/dev/sda4", "/dev/sda3"]
    end

    it "includes the partitions directly used by the RAID" do
      expect(controller.devices_in_md).to include sda3
    end

    it "includes the partitions used by the RAID through an encryption device" do
      expect(controller.devices_in_md).to include cr_sda4.blk_device
    end

    it "does not include the encryption devices used by the RAID" do
      expect(controller.devices_in_md).to_not include cr_sda4
    end
  end

  describe "#add_device" do
    let(:sda1) { Y2Storage::BlkDevice.find_by_name(current_graph, "/dev/sda1") }
    let(:sda2) { Y2Storage::BlkDevice.find_by_name(current_graph, "/dev/sda2") }
    let(:sda3) { Y2Storage::BlkDevice.find_by_name(current_graph, "/dev/sda3") }
    let(:sda4) { Y2Storage::BlkDevice.find_by_name(current_graph, "/dev/sda4") }

    before do
      sda1.remove_descendants
      controller.md.add_device(sda1)
    end

    it "adds the device to the MD RAID, as the last element" do
      controller.add_device(sda2)
      expect(controller.md.sorted_devices.last).to eq sda2
    end

    it "does not remove any previous device from the MD RAID" do
      controller.add_device(sda2)
      expect(controller.md.devices).to include sda1
    end

    it "causes the device to not be available" do
      expect(controller.available_devices).to include sda2
      controller.add_device(sda2)
      expect(controller.available_devices).to_not include sda2
    end

    it "raises an exception if the device is already in the RAID" do
      controller.add_device(sda2)
      expect { controller.add_device }.to raise_error ArgumentError
    end

    it "deletes the previous filesystem from the device" do
      expect(sda2.filesystem).to_not be_nil
      controller.add_device(sda2)
      expect(sda2.filesystem).to be_nil
    end

    it "removes the previous encryption from the device" do
      expect(sda4.encrypted?).to eq true
      controller.add_device(sda4)
      expect(sda4.encrypted?).to eq false
    end

    it "sets the partition identifier to RAID" do
      controller.add_device(sda3)
      controller.add_device(sda4)
      expect(sda3.id.is?(:raid)).to eq true
      expect(sda4.id.is?(:raid)).to eq true
    end
  end

  describe "#remove_device" do
    let(:sda1) { Y2Storage::BlkDevice.find_by_name(current_graph, "/dev/sda1") }
    let(:sda2) { Y2Storage::BlkDevice.find_by_name(current_graph, "/dev/sda2") }

    before do
      sda1.remove_descendants
      sda2.remove_descendants
      controller.md.add_device(sda1)
      controller.md.add_device(sda2)
    end

    it "removes the device from the MD RAID" do
      controller.remove_device(sda2)
      expect(controller.md.devices).to_not include sda2
    end

    it "does not removes any other device from the MD RAID" do
      controller.remove_device(sda2)
      expect(controller.md.devices).to include sda1
    end

    it "makes the device available" do
      expect(controller.available_devices).to_not include sda2
      controller.remove_device(sda2)
      expect(controller.available_devices).to include sda2
    end

    it "raises an exception if trying to remove a device that is not in the RAID" do
      controller.remove_device(sda2)
      expect { controller.remove_device(sda2) }.to raise_error ArgumentError
    end
  end

  describe "#devices_one_step" do
    let(:scenario) { "complex-lvm-encrypt.yml" }
    let(:sda2)    { dev("/dev/sda2") }
    let(:sda3)    { dev("/dev/sda3") }
    let(:sda4)    { dev("/dev/sda4") }
    let(:cr_sda4) { dev("/dev/mapper/cr_sda4") }
    let(:sde1)    { dev("/dev/sde1") }
    let(:cr_sde1) { dev("/dev/mapper/cr_sde1") }
    let(:sde2)    { dev("/dev/sde2") }
    let(:sde3)    { dev("/dev/sde3") }

    before do
      [cr_sde1, sde2, sde3, sda2, sda3, cr_sda4].each do |dev|
        dev.remove_descendants
        controller.md.push_device(dev)
      end
    end

    context "moving up" do
      let(:up) { true }

      context "when only one element is marked" do
        context "if the sid matches one device in the RAID" do
          context "if the device was already the first one" do
            let(:sids) { [cr_sde1.sid] }

            it "changes nothing" do
              controller.devices_one_step(sids, up: up)
              expect(controller.md.sorted_devices).to eq [cr_sde1, sde2, sde3, sda2, sda3, cr_sda4]
            end
          end

          context "if the devices was not the first one" do
            let(:sids) { [sde2.sid] }

            it "moves the device forward in the RAID devices list" do
              controller.devices_one_step(sids, up: up)
              expect(controller.md.sorted_devices).to eq [sde2, cr_sde1, sde3, sda2, sda3, cr_sda4]
            end
          end
        end

        context "if the sid matches the corresponding plain device of an encryption in the RAID" do
          context "if the device was already the first one" do
            let(:sids) { [sde1.sid] }

            it "changes nothing" do
              controller.devices_one_step(sids, up: up)
              expect(controller.md.sorted_devices).to eq [cr_sde1, sde2, sde3, sda2, sda3, cr_sda4]
            end
          end

          context "if the devices was not the first one" do
            let(:sids) { [sda4.sid] }

            it "moves the device forward in the RAID devices list" do
              controller.devices_one_step(sids, up: up)
              expect(controller.md.sorted_devices).to eq [cr_sde1, sde2, sde3, sda2, cr_sda4, sda3]
            end
          end
        end

        context "if the sid matches a device not in the RAID (nor directly or through encryption)" do
          let(:sids) { [dev("/dev/sda1").sid] }

          it "changes nothing" do
            controller.devices_one_step(sids, up: up)
            expect(controller.md.sorted_devices).to eq [cr_sde1, sde2, sde3, sda2, sda3, cr_sda4]
          end
        end

        context "if the sid doesn't match any device in the devicegraph" do
          # sids are always > 42
          let(:sids) { [22] }

          it "changes nothing" do
            controller.devices_one_step(sids, up: up)
            expect(controller.md.sorted_devices).to eq [cr_sde1, sde2, sde3, sda2, sda3, cr_sda4]
          end
        end
      end

      # This was failing in one of the proposed algorithms
      context "when the last two elements were marked" do
        let(:sids) { [sda3.sid, sda4.sid] }

        it "moves them both together as a unit" do
          controller.devices_one_step(sids, up: up)
          expect(controller.md.sorted_devices).to eq [cr_sde1, sde2, sde3, sda3, cr_sda4, sda2]
        end
      end

      context "when several adjacent elements were marked" do
        let(:sids) { [sda3.sid, sda2.sid, sde3.sid] }

        it "moves them all together as a unit" do
          controller.devices_one_step(sids, up: up)
          expect(controller.md.sorted_devices).to eq [cr_sde1, sde3, sda2, sda3, sde2, cr_sda4]
        end
      end

      context "when adjacent and non-adjacents elements were marked" do
        let(:sids) { [sde2.sid, sde1.sid, sda2.sid, sda3.sid] }

        it "moves everything correctly" do
          controller.devices_one_step(sids, up: up)
          expect(controller.md.sorted_devices).to eq [cr_sde1, sde2, sda2, sda3, sde3, cr_sda4]
        end
      end

      context "when all elements but one were marked" do
        let(:sids) { [sde1.sid, sde3.sid, sda2.sid, sda3.sid, sda4.sid] }

        it "moves the non-marked device to the end" do
          controller.devices_one_step(sids, up: up)
          expect(controller.md.sorted_devices).to eq [cr_sde1, sde3, sda2, sda3, cr_sda4, sde2]
        end
      end
    end

    context "moving down" do
      let(:up) { false }

      context "when only one element is marked" do
        context "if the sid matches one device in the RAID" do
          context "if the device was already the last one" do
            let(:sids) { [cr_sda4.sid] }

            it "changes nothing" do
              controller.devices_one_step(sids, up: up)
              expect(controller.md.sorted_devices).to eq [cr_sde1, sde2, sde3, sda2, sda3, cr_sda4]
            end
          end

          context "if the devices was not the last one" do
            let(:sids) { [sde2.sid] }

            it "moves the device backwards in the RAID devices list" do
              controller.devices_one_step(sids, up: up)
              expect(controller.md.sorted_devices).to eq [cr_sde1, sde3, sde2, sda2, sda3, cr_sda4]
            end
          end
        end

        context "if the sid matches the corresponding plain device of an encryption in the RAID" do
          context "if the device was already the last one" do
            let(:sids) { [sda4.sid] }

            it "changes nothing" do
              controller.devices_one_step(sids, up: up)
              expect(controller.md.sorted_devices).to eq [cr_sde1, sde2, sde3, sda2, sda3, cr_sda4]
            end
          end

          context "if the devices was not the last one" do
            let(:sids) { [sde1.sid] }

            it "moves the device backwards in the RAID devices list" do
              controller.devices_one_step(sids, up: up)
              expect(controller.md.sorted_devices).to eq [sde2, cr_sde1, sde3, sda2, sda3, cr_sda4]
            end
          end
        end

        context "if the sid matches a device not in the RAID (nor directly or through encryption)" do
          let(:sids) { [dev("/dev/sda1").sid] }

          it "changes nothing" do
            controller.devices_one_step(sids, up: up)
            expect(controller.md.sorted_devices).to eq [cr_sde1, sde2, sde3, sda2, sda3, cr_sda4]
          end
        end

        context "if the sid doesn't match any device in the devicegraph" do
          # sids are always > 42
          let(:sids) { [22] }

          it "changes nothing" do
            controller.devices_one_step(sids, up: up)
            expect(controller.md.sorted_devices).to eq [cr_sde1, sde2, sde3, sda2, sda3, cr_sda4]
          end
        end
      end

      # This was failing in one of the proposed algorithms
      context "when the first two elements were marked" do
        let(:sids) { [sde1.sid, sde2.sid] }

        it "moves them both together as a unit" do
          controller.devices_one_step(sids, up: up)
          expect(controller.md.sorted_devices).to eq [sde3, cr_sde1, sde2, sda2, sda3, cr_sda4]
        end
      end

      context "when several adjacent elements were marked" do
        let(:sids) { [sde3.sid, sda2.sid, sda3.sid] }

        it "moves them all together as a unit" do
          controller.devices_one_step(sids, up: up)
          expect(controller.md.sorted_devices).to eq [cr_sde1, sde2, cr_sda4, sde3, sda2, sda3]
        end
      end

      context "when adjacent and non-adjacents elements were marked" do
        let(:sids) { [sda2.sid, sda4.sid, sde1.sid, sde2.sid] }

        it "moves everything correctly" do
          controller.devices_one_step(sids, up: up)
          expect(controller.md.sorted_devices).to eq [sde3, cr_sde1, sde2, sda3, sda2, cr_sda4]
        end
      end

      context "when all elements but one were were marked" do
        let(:sids) { [sde1.sid, sde3.sid, sda2.sid, sda3.sid, sda4.sid] }

        it "moves the non-marked device to the beginning" do
          controller.devices_one_step(sids, up: up)
          expect(controller.md.sorted_devices).to eq [sde2, cr_sde1, sde3, sda2, sda3, cr_sda4]
        end
      end
    end
  end

  describe "#md_level" do
    it "returns the level of the Md device" do
      controller.md.md_level = Y2Storage::MdLevel::RAID6
      expect(controller.md_level).to eq Y2Storage::MdLevel::RAID6
    end
  end

  describe "#md_level=" do
    it "sets the level of the Md device" do
      controller.md_level = Y2Storage::MdLevel::RAID10
      expect(controller.md.md_level).to eq Y2Storage::MdLevel::RAID10
    end
  end

  describe "#md_name" do
    it "returns nil for a numeric RAID" do
      expect(controller.md_name).to be_nil
    end

    it "returns the array name for a named RAID" do
      controller.md.name = "/dev/md/foo"
      expect(controller.md_name).to eq "foo"
    end
  end

  describe "#md_name=" do
    context "with a non-empty string" do
      it "sets the array name for the Md device" do
        controller.md_name = "bar"
        expect(controller.md.md_name).to eq "bar"
        expect(controller.md.name).to eq "/dev/md/bar"
        expect(controller.md.numeric?).to eq false
      end
    end

    context "with an empty string" do
      it "restores the numeric name of the Md device" do
        controller.md_name = "bar"
        expect(controller.md.name).to eq "/dev/md/bar"

        controller.md_name = ""
        expect(controller.md.md_name).to be_nil
        expect(controller.md.name).to eq "/dev/md0"
        expect(controller.md.numeric?).to eq true
        expect(controller.md.number).to eq 0
      end
    end

    context "with nil" do
      before do
        # Let's enforce a number != 0 to ensure it's working as expected
        Y2Storage::Md.create(current_graph, "/dev/md0")
      end

      it "restores the numeric name of the Md device" do
        expect(controller.md.name).to eq "/dev/md1"

        controller.md_name = "bar"
        expect(controller.md.name).to eq "/dev/md/bar"

        controller.md_name = nil
        expect(controller.md.md_name).to be_nil
        expect(controller.md.name).to eq "/dev/md1"
        expect(controller.md.numeric?).to eq true
        expect(controller.md.number).to eq 1
      end
    end
  end

  describe "#md_size" do
    let(:md) { instance_double(Y2Storage::Md, size: size) }

    let(:size) { Y2Storage::DiskSize.new(1254) }

    before do
      allow(controller).to receive(:md).and_return(md)
    end

    it "returns the size of the Md device" do
      expect(controller.md_size).to eq(md.size)
    end
  end

  describe "#min_devices" do
    let(:md) { instance_double(Y2Storage::Md, minimal_number_of_devices: min_devices) }

    let(:min_devices) { 12 }

    before do
      allow(controller).to receive(:md).and_return(md)
    end

    it "forwards the call to #minimal_number_of_devices on the Md device" do
      expect(controller.min_devices).to eq(md.minimal_number_of_devices)
    end
  end

  describe "#chunk_size" do
    it "returns the chunk size of the Md device" do
      size = Y2Storage::DiskSize.MiB(10)
      controller.md.chunk_size = size
      expect(controller.chunk_size).to eq size
    end
  end

  describe "#chunk_size=" do
    it "sets the chunk size of the Md device" do
      size = Y2Storage::DiskSize.MiB(10)
      controller.chunk_size = size
      expect(controller.md.chunk_size).to eq size
    end
  end

  describe "#md_parity" do
    it "returns the parity algorithm of the Md device" do
      parity = Y2Storage::MdParity::OFFSET_2
      controller.md.md_parity = parity
      expect(controller.md_parity).to eq parity
    end
  end

  describe "#md_parity=" do
    it "sets the parity algorithm of the Md device" do
      parity = Y2Storage::MdParity::OFFSET_2
      controller.md_parity = parity
      expect(controller.md.md_parity).to eq parity
    end
  end

  describe "#wizard_title" do
    subject(:controller) { described_class.new(md: md) }

    let(:md) { nil }

    it "returns a string containing the name of the Md device" do
      wizard_title = controller.wizard_title
      expect(wizard_title).to be_a(String)
      expect(wizard_title).to include("/dev/md0")
      expect(wizard_title).to_not include("/dev/md/foobar")

      controller.md_name = "foobar"

      wizard_title = controller.wizard_title
      expect(wizard_title).to_not include("/dev/md0")
      expect(wizard_title).to include("/dev/md/foobar")
    end

    context "when a new MD RAID is being created" do
      let(:md) { nil }

      it "returns a string containing the title for adding a Md device" do
        expect(controller.wizard_title).to be_a(String)
        expect(controller.wizard_title).to include("Add RAID")
      end
    end

    context "when a MD RAID is being resized" do
      let(:md) { Y2Storage::Md.create(current_graph, "/dev/md0") }

      it "returns a string containing the title for resizing a Md device" do
        expect(controller.wizard_title).to be_a(String)
        expect(controller.wizard_title).to include("Resize RAID")
      end
    end
  end

  describe "#apply_default_options" do
    before do
      controller.md_level = md_level
    end

    context "when the Md device is a RAID0" do
      let(:md_level) { Y2Storage::MdLevel::RAID0 }

      it "sets chunk size to 64 KiB" do
        controller.apply_default_options
        expect(controller.md.chunk_size).to eq(64.KiB)
      end

      it "does not set the parity" do
        controller.apply_default_options
        expect(controller.md).to_not receive(:md_parity=)
      end
    end

    context "when the Md device is a RAID1" do
      let(:md_level) { Y2Storage::MdLevel::RAID1 }

      it "sets chunk size to 4 KiB" do
        controller.apply_default_options
        expect(controller.md.chunk_size).to eq(4.KiB)
      end

      it "does not set the parity" do
        controller.apply_default_options
        expect(controller.md).to_not receive(:md_parity=)
      end
    end

    context "when the Md device is a RAID5" do
      let(:md_level) { Y2Storage::MdLevel::RAID5 }

      it "sets chunk size to 128 KiB" do
        controller.apply_default_options
        expect(controller.md.chunk_size).to eq(128.KiB)
      end

      it "sets parity to default" do
        controller.apply_default_options
        expect(controller.md.md_parity).to eq(Y2Storage::MdParity::DEFAULT)
      end
    end

    context "when the Md device is a RAID6" do
      let(:md_level) { Y2Storage::MdLevel::RAID6 }

      it "sets chunk size to 128 KiB" do
        controller.apply_default_options
        expect(controller.md.chunk_size).to eq(128.KiB)
      end

      it "sets parity to default" do
        controller.apply_default_options
        expect(controller.md.md_parity).to eq(Y2Storage::MdParity::DEFAULT)
      end
    end

    context "when the Md device is a RAID10" do
      let(:md_level) { Y2Storage::MdLevel::RAID10 }

      it "sets chunk size to 64 KiB" do
        controller.apply_default_options
        expect(controller.md.chunk_size).to eq(64.KiB)
      end

      it "sets parity to default" do
        controller.apply_default_options
        expect(controller.md.md_parity).to eq(Y2Storage::MdParity::DEFAULT)
      end
    end

    context "when the Md device has unknown level" do
      let(:md_level) { Y2Storage::MdLevel::UNKNOWN }

      it "sets chunk size to 64 KiB" do
        controller.apply_default_options
        expect(controller.md.chunk_size).to eq(64.KiB)
      end

      it "does not set the parity" do
        controller.apply_default_options
        expect(controller.md).to_not receive(:md_parity=)
      end
    end

    context "when the Md device is a container" do
      let(:md_level) { Y2Storage::MdLevel::CONTAINER }

      it "sets chunk size to 64 KiB" do
        controller.apply_default_options
        expect(controller.md.chunk_size).to eq(64.KiB)
      end

      it "does not set the parity" do
        controller.apply_default_options
        expect(controller.md).to_not receive(:md_parity=)
      end
    end
  end

  describe "#parity_supported?" do
    before do
      controller.md_level = md_level
    end

    context "when the Md device is a RAID0" do
      let(:md_level) { Y2Storage::MdLevel::RAID0 }

      it "returns false" do
        expect(controller.parity_supported?).to be(false)
      end
    end

    context "when the Md device is a RAID1" do
      let(:md_level) { Y2Storage::MdLevel::RAID1 }

      it "returns false" do
        expect(controller.parity_supported?).to be(false)
      end
    end

    context "when the Md device is a RAID5" do
      let(:md_level) { Y2Storage::MdLevel::RAID5 }

      it "returns true" do
        expect(controller.parity_supported?).to be(true)
      end
    end

    context "when the Md device is a RAID6" do
      let(:md_level) { Y2Storage::MdLevel::RAID6 }

      it "returns true" do
        expect(controller.parity_supported?).to be(true)
      end
    end

    context "when the Md device is a RAID10" do
      let(:md_level) { Y2Storage::MdLevel::RAID10 }

      it "returns true" do
        expect(controller.parity_supported?).to be(true)
      end
    end

    context "when the Md device has unknown level" do
      let(:md_level) { Y2Storage::MdLevel::UNKNOWN }

      it "returns false" do
        expect(controller.parity_supported?).to be(false)
      end
    end

    context "when the Md device a container" do
      let(:md_level) { Y2Storage::MdLevel::CONTAINER }

      it "returns false" do
        expect(controller.parity_supported?).to be(false)
      end
    end
  end
end
