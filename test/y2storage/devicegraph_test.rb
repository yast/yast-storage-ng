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

require_relative "spec_helper"
require "y2storage"

describe Y2Storage::Devicegraph do
  # Used to check sorting by name
  def less_than_next?(device, collection)
    next_dev = collection[collection.index(device) + 1]
    next_dev.nil? || device.compare_by_name(next_dev) < 0
  end

  describe "#safe_copy" do
    before do
      fake_scenario("mixed_disks")
    end

    subject { fake_devicegraph }

    context "when it tries to copy into itself" do
      let(:other_devicegraph) { subject }

      it "does not perform the copy" do
        expect(subject).to_not receive(:copy)
        subject.safe_copy(other_devicegraph)
      end

      it "returns false" do
        expect(subject.safe_copy(other_devicegraph)).to eq(false)
      end
    end

    context "when it tries to copy into another devicegraph" do
      let(:other_devicegraph) do
        devicegraph = subject.dup
        disk = devicegraph.find_by_name("/dev/sda")
        disk.delete_partition_table
        devicegraph
      end

      it "copies the content into the given devicegraph" do
        expect(subject).to_not eq(other_devicegraph)
        subject.safe_copy(other_devicegraph)
        expect(subject).to eq(other_devicegraph)
      end

      it "returns true" do
        expect(subject.safe_copy(other_devicegraph)).to eq(true)
      end
    end
  end

  describe "#actiongraph" do
    def with_sda2_deleted(initial_graph)
      graph = initial_graph.dup
      Y2Storage::Disk.find_by_name(graph, "/dev/sda").partition_table.delete_partition("/dev/sda2")
      graph
    end

    context "if both devicegraphs are equivalent" do
      before { Y2Storage::StorageManager.create_test_instance }

      let(:initial_graph) { Y2Storage::Devicegraph.new_from_file(input_file_for("mixed_disks")) }
      subject(:devicegraph) { initial_graph.dup }

      it "returns an empty actiongraph" do
        result = devicegraph.actiongraph(from: initial_graph)
        expect(result).to be_a Y2Storage::Actiongraph
        expect(result).to be_empty
      end
    end

    context "if both devicegraphs are not equivalent" do
      before { Y2Storage::StorageManager.create_test_instance }

      let(:initial_graph) { Y2Storage::Devicegraph.new_from_file(input_file_for("mixed_disks")) }
      subject(:devicegraph) { with_sda2_deleted(initial_graph) }

      it "returns an actiongraph with the needed actions" do
        result = devicegraph.actiongraph(from: initial_graph)
        expect(result).to be_a Y2Storage::Actiongraph
        expect(result).to_not be_empty
      end
    end

    context "if no initial devicegraph is provided" do
      before { fake_scenario("mixed_disks") }

      subject(:devicegraph) { with_sda2_deleted(fake_devicegraph) }

      it "uses the probed devicegraph as starting point" do
        probed = Y2Storage::StorageManager.instance.probed
        actiongraph1 = devicegraph.actiongraph(from: probed)
        actiongraph2 = devicegraph.actiongraph
        expect(actiongraph1.commit_actions_as_strings).to eq(actiongraph2.commit_actions_as_strings)
      end
    end
  end

  describe "#blk_filesystems" do
    before { fake_scenario("complex-lvm-encrypt") }
    subject(:list) { fake_devicegraph.blk_filesystems }
    let(:device_names) { list.map { |i| i.blk_devices.first.name } }

    it "returns a array of block filesystems" do
      expect(list).to be_a Array
      expect(list.map { |i| i.is?(:blk_filesystem) }).to all(be(true))
    end

    it "finds the filesystems on plain partitions" do
      expect(device_names).to include("/dev/sda1")
      expect(device_names).to include("/dev/sda2")
      expect(device_names).to include("/dev/sdf1")
    end

    it "finds the filesystems on encrypted partitions" do
      expect(device_names).to include("/dev/mapper/cr_sda4")
    end

    it "finds the filesystems on plain LVs" do
      expect(device_names).to include("/dev/vg0/lv1")
      expect(device_names).to include("/dev/vg0/lv2")
      expect(device_names).to include("/dev/vg1/lv1")
    end

    it "finds the filesystems on encrypted LVs" do
      expect(device_names).to include("/dev/mapper/cr_vg1_lv2")
    end
  end

  describe "#filesystems" do
    before { fake_scenario("complex-lvm-encrypt") }
    subject(:list) { fake_devicegraph.filesystems }

    it "returns a array of filesystems" do
      expect(list).to be_a Array
      expect(list.map { |i| i.is?(:filesystem) }).to all(be(true))
    end

    it "finds all the filesystems" do
      expect(list.size).to eq 9
    end
  end

  describe "#lvm_pvs" do
    before { fake_scenario("complex-lvm-encrypt") }
    subject(:list) { fake_devicegraph.lvm_pvs }
    let(:device_names) { list.map { |i| i.blk_device.name } }

    it "returns a array of PVs" do
      expect(list).to be_a Array
      expect(list.map { |i| i.is?(:lvm_pv) }).to all(be(true))
    end

    it "finds the PVs on plain partitions" do
      expect(device_names).to include("/dev/sde2")
    end

    it "finds the PVs on encrypted partitions" do
      expect(device_names).to include("/dev/mapper/cr_sde1")
    end

    it "finds the PVs on plain disks" do
      expect(device_names).to include("/dev/sdg")
    end

    it "finds the PVs on encrypted disks" do
      expect(device_names).to include("/dev/mapper/cr_sdd")
    end
  end

  describe "#filesystem_in_network?" do
    before do
      allow(devicegraph).to receive(:filesystems).and_return([filesystem])
    end
    let(:blk_device) { Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name) }
    let(:filesystem) { blk_device.blk_filesystem }
    let(:devicegraph) { Y2Storage::Devicegraph.new_from_file(input_file_for("mixed_disks")) }
    let(:dev_name) { "/dev/sdb2" }

    context "when filesystem is in network" do
      before do
        allow(filesystem).to receive(:in_network?).and_return(true)
      end

      it "returns true" do
        expect(devicegraph.filesystem_in_network?("/")).to eq true
      end
    end

    context "when filesystem is not in network" do
      before do
        allow(filesystem).to receive(:in_network?).and_return(false)
      end
      let(:devicegraph) { Y2Storage::Devicegraph.new_from_file(input_file_for("mixed_disks")) }

      it "returns false" do
        expect(devicegraph.filesystem_in_network?("/")).to eq false
      end
    end

    context "when mountpoint does not exist" do
      before do
        allow(filesystem).to receive(:in_network?).and_return(true)
      end
      let(:devicegraph) { Y2Storage::Devicegraph.new_from_file(input_file_for("mixed_disks")) }

      it "returns false" do
        expect(devicegraph.filesystem_in_network?("no_mountpoint")).to eq false
      end
    end
  end

  describe "#raids" do
    before do
      fake_scenario("mixed_disks")
    end

    subject(:devicegraph) { fake_devicegraph }

    context "when there are RAIDs" do
      before do
        Y2Storage::DmRaid.create(devicegraph, "/dev/mapper/imsm0")
        Y2Storage::DmRaid.create(devicegraph, "/dev/mapper/imsm1")

        Y2Storage::MdMember.create(devicegraph, "/dev/md0")
        Y2Storage::MdMember.create(devicegraph, "/dev/md/1")
        Y2Storage::MdMember.create(devicegraph, "/dev/md2")

        Y2Storage::Md.create(devicegraph, "/dev/md3")
        Y2Storage::Md.create(devicegraph, "/dev/md/4")
        Y2Storage::Md.create(devicegraph, "/dev/md5")
      end

      it "includes all RAIDs sorted by name" do
        expect(devicegraph.raids.map(&:name)).to eq [
          "/dev/mapper/imsm0",
          "/dev/mapper/imsm1",
          "/dev/md/1",
          "/dev/md/4",
          "/dev/md0",
          "/dev/md2",
          "/dev/md3",
          "/dev/md5"
        ]
      end
    end

    context "when there are no RAIDs" do
      it "does not include any device" do
        expect(devicegraph.raids).to be_empty
      end
    end
  end

  describe "#bios_raids" do
    before do
      fake_scenario("mixed_disks")
    end

    subject(:devicegraph) { fake_devicegraph }

    context "when there are BIOS RAIDs" do
      before do
        Y2Storage::DmRaid.create(devicegraph, "/dev/mapper/imsm0")
        Y2Storage::DmRaid.create(devicegraph, "/dev/mapper/imsm1")

        Y2Storage::MdMember.create(devicegraph, "/dev/md0")
        Y2Storage::MdMember.create(devicegraph, "/dev/md/1")
        Y2Storage::MdMember.create(devicegraph, "/dev/md2")
      end

      it "includes all DM RAIDs and BIOS MD RAIDs sorted by name" do
        expect(devicegraph.bios_raids.map(&:name)).to eq [
          "/dev/mapper/imsm0",
          "/dev/mapper/imsm1",
          "/dev/md/1",
          "/dev/md0",
          "/dev/md2"
        ]
      end
    end

    context "when there are not BIOS RAIDs" do
      before do
        Y2Storage::Md.create(devicegraph, "/dev/md/0")
      end

      it "does not include any device" do
        expect(devicegraph.bios_raids).to be_empty
      end
    end
  end

  describe "#software_raids" do
    before do
      fake_scenario("mixed_disks")
    end

    subject(:devicegraph) { fake_devicegraph }

    context "when there are Software RAIDs" do
      before do
        Y2Storage::Md.create(devicegraph, "/dev/md0")
        Y2Storage::Md.create(devicegraph, "/dev/md/1")
        Y2Storage::Md.create(devicegraph, "/dev/md2")
      end

      it "includes all Software RAIDs sorted by name" do
        expect(devicegraph.software_raids.map(&:name)).to eq [
          "/dev/md/1",
          "/dev/md0",
          "/dev/md2"
        ]
      end
    end

    context "when there are not Software RAIDs" do
      before do
        Y2Storage::MdMember.create(devicegraph, "/dev/md0")
      end

      it "does not include any device" do
        expect(devicegraph.software_raids).to be_empty
      end
    end
  end

  describe "#find_by_name" do
    before { fake_scenario("complex-lvm-encrypt") }
    subject(:devicegraph) { fake_devicegraph }

    context "there is BlkDevice with given name" do
      it "returns that device" do
        blk_device = devicegraph.find_by_name("/dev/sda1")

        expect(blk_device).to_not be_nil
        expect(blk_device.name).to eq "/dev/sda1"
      end
    end

    context "there is LvmVg with given name" do
      it "returns that device" do
        blk_device = devicegraph.find_by_name("/dev/vg0")

        expect(blk_device).to_not be_nil
        expect(blk_device.name).to eq "/dev/vg0"
      end
    end

    context "given name does not exists" do
      it "returns nil" do
        blk_device = devicegraph.find_by_name("/dev/drunk_chameleon")

        expect(blk_device).to be_nil
      end
    end
  end

  describe "#find_by_any_name" do
    before { fake_scenario("complex-lvm-encrypt") }
    subject(:devicegraph) { Y2Storage::StorageManager.instance.staging }

    context "if there is BlkDevice with given name" do
      it "returns that device" do
        blk_device = devicegraph.find_by_any_name("/dev/sda1")

        expect(blk_device).to_not be_nil
        expect(blk_device.name).to eq "/dev/sda1"
      end

      it "does not perform a system lookup" do
        expect(Y2Storage::BlkDevice).to_not receive(:find_by_any_name)
      end
    end

    context "if there is LvmVg with given name" do
      it "returns that device" do
        blk_device = devicegraph.find_by_name("/dev/vg0")

        expect(blk_device).to_not be_nil
        expect(blk_device.name).to eq "/dev/vg0"
      end

      it "does not perform a system lookup" do
        expect(Y2Storage::BlkDevice).to_not receive(:find_by_any_name)
      end
    end

    context "if there is BlkDevice containing a filesystem with a matching UUID" do
      it "returns that device" do
        blk_device = devicegraph.find_by_any_name("/dev/disk/by-uuid/abcdefgh-ijkl-mnop-qrst-uvwxyzzz")

        expect(blk_device).to_not be_nil
        expect(blk_device.name).to eq "/dev/mapper/cr_vg1_lv2"
      end

      it "does not perform a system lookup" do
        expect(Y2Storage::BlkDevice).to_not receive(:find_by_any_name)
      end
    end

    context "if there is BlkDevice containing a filesystem with a matching label" do
      it "returns that device" do
        blk_device = devicegraph.find_by_any_name("/dev/disk/by-label/root")

        expect(blk_device).to_not be_nil
        expect(blk_device.name).to eq "/dev/sda2"
      end

      it "does not perform a system lookup" do
        expect(Y2Storage::BlkDevice).to_not receive(:find_by_any_name)
      end
    end

    context "if no device is matched by its name or any of the known udev names" do
      let(:name) { "/dev/drunk_chameleon" }

      before do
        allow(Y2Storage::StorageManager.instance).to receive(:committed?).and_return committed
      end

      context "if the probed devicegraph is still up-to-date" do
        let(:committed) { false }

        it "performs a system lookup on the probed devicegraph" do
          expect(Y2Storage::BlkDevice).to receive(:find_by_any_name).with(fake_devicegraph, name)
          devicegraph.find_by_any_name(name)
        end

        context "if the lookup returns a valid probed device" do
          let(:probed_device) { fake_devicegraph.find_by_name("/dev/sdf1") }

          before do
            allow(Y2Storage::BlkDevice).to receive(:find_by_any_name).and_return probed_device
          end

          context "and that device still exists in the target devicegraph" do
            it "returns the corresponding device" do
              found = devicegraph.find_by_any_name(name)
              expected = devicegraph.find_by_name("/dev/sdf1")
              expect(found).to eq expected
            end
          end

          context "and there is no equivalent device in the target devicegraph" do
            before do
              partition = devicegraph.find_by_name("/dev/sdf1")
              partition.partition_table.delete_partition(partition)
            end

            it "returns nil" do
              found = devicegraph.find_by_any_name(name)
              expect(found).to be_nil
            end
          end
        end

        context "if the lookup finds nothing" do
          before do
            allow(Y2Storage::BlkDevice).to receive(:find_by_any_name).and_return nil
          end

          it "returns nil" do
            expect(devicegraph.find_by_any_name(name)).to be_nil
          end
        end
      end

      context "if the probed devicegraph may be outdated" do
        let(:committed) { true }

        it "returns nil" do
          expect(devicegraph.find_by_any_name(name)).to be_nil
        end

        it "does not perform a system lookup" do
          expect(Y2Storage::BlkDevice).to_not receive(:find_by_any_name)
        end
      end
    end
  end

  describe "#disk_devices" do
    before { fake_scenario(scenario) }
    subject(:graph) { fake_devicegraph }

    context "if there are no multi-disk devices" do
      let(:scenario) { "autoyast_drive_examples" }

      it "returns an array of devices" do
        expect(graph.disk_devices).to be_an Array
        expect(graph.disk_devices).to all(be_a(Y2Storage::Device))
      end

      it "includes all partitionable disks and DASDs sorted by name" do
        expect(graph.disk_devices.map(&:name)).to eq [
          "/dev/dasda", "/dev/dasdb", "/dev/nvme0n1", "/dev/sda", "/dev/sdb",
          "/dev/sdc", "/dev/sdd", "/dev/sdf", "/dev/sdh", "/dev/sdi", "/dev/sdj", "/dev/sdaa"
        ]
      end
    end

    context "if there are multipath devices" do
      let(:scenario) { "empty-dasd-and-multipath.xml" }

      it "returns a sorted array of devices" do
        devices = graph.disk_devices
        expect(devices).to be_an Array
        expect(devices).to all(be_a(Y2Storage::Device))
        expect(devices).to all(satisfy { |dev| less_than_next?(dev, devices) })
      end

      it "includes all multipath devices" do
        expect(graph.disk_devices.map(&:name)).to include(
          "/dev/mapper/36005076305ffc73a00000000000013b4",
          "/dev/mapper/36005076305ffc73a00000000000013b5"
        )
      end

      it "includes all disks and DASDs that are not part of a multipath" do
        expect(graph.disk_devices.map(&:name)).to include("/dev/dasdb", "/dev/sde")
      end

      it "does not include individual disks and DASDs from the multipaths" do
        expect(graph.disk_devices.map(&:name)).to_not include(
          "/dev/sda", "/dev/sdb", "/dev/sdc", "/dev/sdd"
        )
      end
    end

    context "if there are DM RAIDs" do
      let(:scenario) { "empty-dm_raids.xml" }

      it "returns a sorted array of devices" do
        devices = graph.disk_devices
        expect(devices).to be_an Array
        expect(devices).to all(be_a(Y2Storage::Device))
        expect(devices).to all(satisfy { |dev| less_than_next?(dev, devices) })
      end

      it "includes all DM RAIDs" do
        expect(graph.disk_devices.map(&:name)).to include(
          "/dev/mapper/isw_ddgdcbibhd_test1", "/dev/mapper/isw_ddgdcbibhd_test2"
        )
      end

      it "includes all disks and DASDs that are not part of a DM RAID" do
        expect(graph.disk_devices.map(&:name)).to include("/dev/sda")
      end

      it "does not include individual disks or DASDs from the DM RAID" do
        expect(graph.disk_devices.map(&:name)).to_not include("/dev/sdb", "/dev/sdc")
      end
    end

    context "if there are MD Member RAIDs" do
      let(:scenario) { "md-imsm1-devicegraph.xml" }

      it "returns a sorted array of devices" do
        devices = graph.disk_devices
        expect(devices).to be_an Array
        expect(devices).to all(be_a(Y2Storage::Device))
        expect(devices).to all(satisfy { |dev| less_than_next?(dev, devices) })
      end

      it "includes all MD Member RAIDs" do
        expect(graph.disk_devices.map(&:name)).to include(
          "/dev/md/a", "/dev/md/b"
        )
      end

      it "includes all disks and DASDs that are not part of a MD Member RAID" do
        expect(graph.disk_devices.map(&:name)).to include("/dev/sda")
      end

      it "does not include individual disks or DASDs from the MD Member RAID" do
        expect(graph.disk_devices.map(&:name))
          .to_not include("/dev/sdb", "/dev/sdc", "/dev/sdd")
      end
    end

    context "if there are several kind of DASDs" do
      let(:scenario) { "kinds-of-dasd.xml" }

      it "returns a sorted array of devices" do
        devices = graph.disk_devices
        expect(devices).to be_an Array
        expect(devices).to all(be_a(Y2Storage::Device))
        expect(devices).to all(satisfy { |dev| less_than_next?(dev, devices) })
      end

      it "includes all disks and DASDs that can hold a partition table" do
        expect(graph.disk_devices.map(&:name)).to include(
          "/dev/sda", "/dev/dasda", "/dev/dasdc", "/dev/dasdd", "/dev/dasde"
        )
      end

      it "does not include unformatted DASDs" do
        expect(graph.disk_devices.map(&:name)).to_not include("/dev/dasdb")
      end
    end

    context "if there are zero-size devices" do
      let(:scenario) { "zero-size_disk" }

      it "does not include zero-size devices" do
        expect(graph.disks).to include(an_object_having_attributes(name: "/dev/sda"))
        expect(graph.disk_devices).to_not include(an_object_having_attributes(name: "/dev/sda"))
      end
    end
  end

  describe "#remove_md" do
    subject(:devicegraph) { Y2Storage::StorageManager.instance.staging }

    before do
      fake_scenario("md_raid.xml")

      # Create a Vg over the md raid
      md = Y2Storage::Md.find_by_name(devicegraph, md_name)
      md.remove_descendants

      vg = Y2Storage::LvmVg.create(devicegraph, vg_name)
      vg.add_lvm_pv(md)

      sda3.remove_descendants
      vg.add_lvm_pv(sda3)

      vg.create_lvm_lv("lv1", Y2Storage::DiskSize.GiB(1))
    end

    let(:md_name) { "/dev/md/md0" }
    let(:vg_name) { "vg0" }
    let(:sda3) { devicegraph.find_by_name("/dev/sda3") }

    it "removes the given md device" do
      md = Y2Storage::Md.find_by_name(devicegraph, md_name)
      expect(md).to_not be_nil

      devicegraph.remove_md(md)

      md = Y2Storage::Md.find_by_name(devicegraph, md_name)
      expect(md).to be_nil
    end

    it "removes all md descendants" do
      md = Y2Storage::Md.find_by_name(devicegraph, md_name)
      descendants_sid = md.descendants.map(&:sid)

      expect(descendants_sid).to_not be_empty

      devicegraph.remove_md(md)

      existing_descendants = descendants_sid.map { |sid| devicegraph.find_device(sid) }.compact
      expect(existing_descendants).to be_empty
    end

    it "removes the orphans resulting from deleting the descendants" do
      md = Y2Storage::Md.find_by_name(devicegraph, md_name)

      expect(sda3.lvm_pv).to_not be_nil
      devicegraph.remove_md(md)
      expect(sda3.lvm_pv).to be_nil
    end

    it "does not remove other devices" do
      md = Y2Storage::Md.find_by_name(devicegraph, md_name)

      expect(sda3.exists_in_devicegraph?(devicegraph)).to eq true
      devicegraph.remove_md(md)
      expect(sda3.exists_in_devicegraph?(devicegraph)).to eq true
    end

    context "when the md does not exist in the devicegraph" do
      before do
        Y2Storage::Md.create(other_devicegraph, md1_name)
      end

      let(:other_devicegraph) { devicegraph.dup }

      let(:md1_name) { "/dev/md/md1" }

      it "raises an exception and does not remove the md" do
        md1 = Y2Storage::Md.find_by_name(other_devicegraph, md1_name)

        expect { devicegraph.remove_md(md1) }.to raise_error(ArgumentError)
        expect(Y2Storage::Md.find_by_name(other_devicegraph, md1_name)).to_not be_nil
      end
    end
  end

  describe "#remove_lvm_vg" do
    subject(:devicegraph) { Y2Storage::StorageManager.instance.staging }

    let(:vg_name) { "/dev/vg1" }

    before { fake_scenario("lvm-two-vgs") }

    it "removes the given LvmVg device" do
      vg = devicegraph.find_by_name(vg_name)

      expect(vg).to_not be_nil
      devicegraph.remove_lvm_vg(vg)
      expect(devicegraph.find_by_name(vg_name)).to be_nil
    end

    it "removes all VG descendants" do
      vg = devicegraph.find_by_name(vg_name)
      descendants_sid = vg.descendants.map(&:sid)

      expect(descendants_sid).to_not be_empty
      devicegraph.remove_lvm_vg(vg)

      survivors = descendants_sid.map { |sid| devicegraph.find_device(sid) }.compact
      expect(survivors).to be_empty
    end

    it "removes all the LvmPv devices associated to the VG" do
      vg = devicegraph.find_by_name(vg_name)
      pv_sids = vg.lvm_pvs.map(&:sid)

      expect(pv_sids).to_not be_empty
      devicegraph.remove_lvm_vg(vg)
      surviving_pvs = pv_sids.map { |sid| devicegraph.find_device(sid) }.compact
      expect(surviving_pvs).to be_empty
    end

    it "does not remove the block devices hosting the PVs" do
      vg = devicegraph.find_by_name(vg_name)
      blk_devices = vg.lvm_pvs.map(&:blk_device)

      expect(blk_devices).to_not be_empty
      devicegraph.remove_lvm_vg(vg)
      surviving_devs = blk_devices.map { |dev| devicegraph.find_device(dev.sid) }
      expect(surviving_devs).to eq blk_devices
    end

    context "when the VG does not exist in the devicegraph" do
      let(:other_devicegraph) { devicegraph.dup }
      let(:new_vg_name) { "new_vg" }

      before do
        Y2Storage::LvmVg.create(other_devicegraph, new_vg_name)
      end

      it "raises an exception and does not remove the VG" do
        vg = Y2Storage::LvmVg.find_by_vg_name(other_devicegraph, new_vg_name)

        expect { devicegraph.remove_lvm_vg(vg) }.to raise_error ArgumentError
        expect(Y2Storage::LvmVg.find_by_vg_name(other_devicegraph, new_vg_name)).to_not be_nil
      end
    end
  end

  describe "#to_xml" do
    before { fake_scenario("empty_hard_disk_50GiB") }

    subject(:devicegraph) { fake_devicegraph }

    def create_partition(disk)
      disk.ensure_partition_table
      slot = disk.partition_table.unused_partition_slots.first
      disk.partition_table.create_partition(slot.name, slot.region, Y2Storage::PartitionType::PRIMARY)
    end

    it "returns a string" do
      expect(devicegraph.to_xml).to be_a(String)
    end

    it "contains the xml representation of the devicegraph" do
      expect(devicegraph.to_xml).to match(/^\<\?xml/)
      expect(devicegraph.to_xml.scan(/\<Disk\>/).size).to eq(1)
      expect(devicegraph.to_xml.scan(/\<Partition\>/).size).to eq(0)

      create_partition(devicegraph.disks.first)

      expect(devicegraph.to_xml.scan(/\<Partition\>/).size).to eq(1)
    end
  end

  describe "#blk_devices" do
    before { fake_scenario("complex-lvm-encrypt") }
    subject(:list) { fake_devicegraph.blk_devices }

    it "returns a sorted array of block devices" do
      expect(list).to be_a Array
      expect(list).to all(be_a(Y2Storage::BlkDevice))
      expect(list).to all(satisfy { |dev| less_than_next?(dev, list) })
    end

    it "finds all the devices" do
      expect(list.size).to eq 24
    end

    it "does not include other devices like volume groups" do
      expect(fake_devicegraph.lvm_vgs).to_not be_empty
      vg1 = fake_devicegraph.lvm_vgs.first
      expect(list).to_not include vg1
    end
  end
end
