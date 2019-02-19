#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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
require "y2partitioner/actions/controllers/bcache"

describe Y2Partitioner::Actions::Controllers::Bcache do
  before do
    devicegraph_stub(scenario)
  end

  subject(:controller) { described_class.new(device) }

  let(:device) { nil }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  def dev(name)
    result = Y2Storage::BlkDevice.find_by_name(current_graph, name)
    result ||= Y2Storage::LvmVg.all(current_graph).find { |i| i.name == name }
    result
  end

  shared_examples "usable devices" do
    def name_of_devices
      devices = controller.send(testing_method)
      devices = devices.select { |d| d.respond_to?(:name) }

      devices.map(&:name)
    end

    let(:scenario) { "complex-lvm-encrypt.yml" }

    it "returns an array of block devices" do
      expect(controller.send(testing_method)).to be_an(Array)
      expect(controller.send(testing_method)).to all be_a(Y2Storage::BlkDevice)
    end

    it "includes partitions with an unmounted filesystem" do
      expect(name_of_devices).to include("/dev/sda2", "/dev/sde3")
    end

    it "excludes partitions with a mount point" do
      expect(name_of_devices).to include("/dev/sda2", "/dev/sde3")

      sda2 = dev("/dev/sda2")
      sda2.filesystem.mount_path = "/var"
      sde3 = dev("/dev/sde3")
      sde3.filesystem.mount_path = "swap"

      expect(name_of_devices).to_not include("/dev/sda2", "/dev/sde3")
    end

    it "excludes partitions that are part of an LVM" do
      expect(name_of_devices).to_not include("/dev/sde1", "/dev/sde2")
      sda3 = dev("/dev/sda3")
      expect(controller.send(testing_method)).to include sda3

      vg0 = dev("/dev/vg0")
      vg0.add_lvm_pv(sda3)
      expect(controller.send(testing_method)).to_not include sda3
    end

    it "excludes partitions that are part of a MD Raid" do
      sda3 = dev("/dev/sda3")
      expect(controller.send(testing_method)).to include sda3

      new_md = Y2Storage::Md.create(current_graph, "/dev/md0")
      new_md.add_device(sda3)
      expect(controller.send(testing_method)).to_not include sda3
    end

    it "includes disks with no partition tables" do
      expect(name_of_devices).to include "/dev/sdb"
    end

    it "includes disks with empty partition tables" do
      sdb = dev("/dev/sdb")
      sdb.create_partition_table(Y2Storage::PartitionTables::Type::GPT)

      expect(name_of_devices).to include "/dev/sdb"
    end

    it "excludes disks with partitions" do
      expect(name_of_devices).to_not include "/dev/sdf"
    end

    it "excludes disks with a mount point" do
      expect(name_of_devices).to include "/dev/sdb"

      sdb = dev("/dev/sdb")
      sdb.create_filesystem(Y2Storage::Filesystems::Type::EXT3)
      sdb.filesystem.mount_path = "/var"

      expect(name_of_devices).to_not include "/dev/sdb"
    end

    it "excludes disks that are part of an LVM" do
      expect(name_of_devices).to_not include "/dev/sdg"
    end

    it "excludes disks that are part of a MD Raid" do
      sdb = dev("/dev/sdb")
      expect(controller.send(testing_method)).to include sdb

      new_md = Y2Storage::Md.create(current_graph, "/dev/md0")
      new_md.add_device(sdb)
      expect(controller.send(testing_method)).to_not include sdb
    end

    context "when there are extended partitions" do
      let(:scenario) { "lvm-two-vgs.yml" }

      it "excludes extended partitions" do
        expect(name_of_devices).to_not include("/dev/sda3")
      end
    end

    context "when there are DM RAIDs" do
      let(:scenario) { "empty-dm_raids.xml" }

      it "excludes disks that are part of a DM RAID" do
        expect(name_of_devices).to_not include("/dev/sdb", "/dev/sdc")
      end
    end

    context "when there are bcaches" do
      let(:scenario) { "bcache2.xml" }

      it "excludes Bcaches" do
        expect(name_of_devices).to_not include("/dev/bcache0", "/dev/bcache1", "/dev/bcache2")
      end

      it "excludes partitions from a Bcache" do
        expect(name_of_devices).to_not include("/dev/bcache1p1", "/dev/bcache1p2")
      end

      it "excludes devices used as backing device" do
        expect(name_of_devices).to_not include("/dev/sdb2")
      end

      it "excludes devices used as caching device" do
        expect(name_of_devices).to_not include("/dev/sdb1")
      end
    end
  end

  describe "#suitable_backing_devices" do
    context "when the bcache device is being created" do
      let(:device) { nil }

      let(:testing_method) { :suitable_backing_devices }

      include_examples "usable devices"

      context "when there are caching sets" do
        let(:scenario) { "bcache2.xml" }

        it "excludes all caching set devices" do
          bcache_csets = Y2Storage::BcacheCset.all(current_graph)

          expect(controller.suitable_backing_devices).to_not include(bcache_csets)
        end
      end
    end

    context "when the bcache device is being edited" do
      let(:scenario) { "bcache2.xml" }

      let(:device) { current_graph.find_by_name("/dev/bcache0") }

      it "returns an array of block devices" do
        expect(controller.suitable_backing_devices).to be_an(Array)
        expect(controller.suitable_backing_devices).to all be_a(Y2Storage::BlkDevice)
      end

      it "only includes its backing device" do
        expect(controller.suitable_backing_devices.map(&:name)).to contain_exactly("/dev/sdb2")
      end
    end
  end

  describe "#suitable_caching_devices" do
    let(:testing_method) { :suitable_caching_devices }

    include_examples "usable devices"

    context "when there are caching sets" do
      let(:scenario) { "bcache1.xml" }

      before do
        vda1 = current_graph.find_by_name("/dev/vda1")
        vda1.create_bcache_cset
      end

      it "includes all caching set devices" do
        bcache_csets = Y2Storage::BcacheCset.all(current_graph)

        expect(bcache_csets.size).to eq(2)

        expect(controller.suitable_caching_devices).to include(*bcache_csets)
      end
    end
  end

  describe "#create_bcache" do
    let(:scenario) { "bcache2.xml" }

    let(:backing_device) { current_graph.find_by_name("/dev/sda1") }

    let(:caching_device) { nil }

    let(:options) { { cache_mode: Y2Storage::CacheMode::WRITEBACK } }

    let(:system_backing_device) { system_graph.find_by_name(backing_device.name) }

    let(:system_graph) { Y2Partitioner::DeviceGraphs.instance.system }

    it "creates a new bcache over the given backing device" do
      expect(current_graph.find_by_name("/dev/bcache3")).to be_nil

      subject.create_bcache(backing_device, caching_device, options)

      bcache = current_graph.find_by_name("/dev/bcache3")

      expect(bcache).to_not be_nil
      expect(bcache.backing_device).to eq(backing_device)
    end

    it "creates a new bcache with the given cache mode" do
      expect(current_graph.find_by_name("/dev/bcache3")).to be_nil

      subject.create_bcache(backing_device, caching_device, options)

      bcache = current_graph.find_by_name("/dev/bcache3")

      expect(bcache).to_not be_nil
      expect(bcache.cache_mode).to eq(options[:cache_mode])
    end

    context "when the given backing device has some content on disk" do
      it "creates a new bcache without the content of the backing device" do
        expect(system_backing_device.descendants).to_not be_empty

        subject.create_bcache(backing_device, caching_device, options)

        bcache = current_graph.find_by_name("/dev/bcache3")

        expect(bcache.descendants).to be_empty
      end
    end

    context "when the given backing device has content only in memory" do
      before do
        backing_device.remove_descendants
        backing_device.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
      end

      it "creates a new bcache with the content of the backing device" do
        content_before = backing_device.descendants
        expect(content_before).to_not be_empty

        subject.create_bcache(backing_device, caching_device, options)

        bcache = current_graph.find_by_name("/dev/bcache3")

        expect(bcache.descendants).to_not be_empty
        expect(bcache.descendants).to eq(content_before)
      end
    end

    context "when non caching device is given" do
      let(:caching_device) { nil }

      it "creates a new bcache without an associated caching set" do
        expect(current_graph.find_by_name("/dev/bcache3")).to be_nil

        subject.create_bcache(backing_device, caching_device, options)

        bcache = current_graph.find_by_name("/dev/bcache3")

        expect(bcache).to_not be_nil
        expect(bcache.bcache_cset).to be_nil
      end
    end

    context "when a blk device is given for caching" do
      let(:caching_device) { current_graph.find_by_name("/dev/sda2") }

      it "creates a new bcache with the given device for caching" do
        expect(current_graph.find_by_name("/dev/bcache3")).to be_nil

        subject.create_bcache(backing_device, caching_device, options)

        bcache = current_graph.find_by_name("/dev/bcache3")

        expect(bcache).to_not be_nil
        expect(bcache.bcache_cset.blk_devices.first).to eq(caching_device)
      end
    end

    context "when a existing caching set is given for caching" do
      let(:caching_device) { current_graph.bcache_csets.first }

      it "creates a new bcache with the given caching set for caching" do
        expect(current_graph.find_by_name("/dev/bcache3")).to be_nil

        subject.create_bcache(backing_device, caching_device, options)

        bcache = current_graph.find_by_name("/dev/bcache3")

        expect(bcache).to_not be_nil
        expect(bcache.bcache_cset).to eq(caching_device)
      end
    end
  end

  shared_examples "update previous caching" do
    def call_testing_method
      subject.send(*testing_method)
    end

    context "and the previous caching set was being used only by this bcache" do
      let(:previous_caching_device) { current_graph.find_by_name("/dev/sda1") }

      it "removes the previous caching set" do
        expect(previous_caching_device.in_bcache_cset).to_not be_nil

        call_testing_method

        expect(previous_caching_device.in_bcache_cset).to be_nil
      end

      it "restores the previous status of the caching device" do
        expect(previous_caching_device.filesystem).to be_nil

        call_testing_method

        expect(previous_caching_device.filesystem).to_not be_nil
      end
    end

    context "and the previous caching set was being used by several bcache devices" do
      let(:previous_caching_device) { Y2Storage::BcacheCset.all(current_graph).first }

      it "does not remove the previous caching set" do
        call_testing_method

        expect(previous_caching_device).to_not be_nil
      end
    end
  end

  describe "#update_bcache" do
    let(:scenario) { "bcache2.xml" }

    before do
      sda2 = current_graph.find_by_name("/dev/sda2")
      described_class.new.create_bcache(sda2, previous_caching_device, {})
    end

    let(:device) { current_graph.find_by_name("/dev/bcache3") }

    let(:previous_caching_device) { nil }

    let(:caching_device) { nil }

    let(:options) { { cache_mode: Y2Storage::CacheMode::WRITEBACK } }

    shared_examples "detach actions" do
      it "detaches its previous caching set" do
        previous_sid = device.bcache_cset.sid

        subject.update_bcache(caching_device, options)

        detached = device.bcache_cset.nil? || device.bcache_cset.sid != previous_sid

        expect(detached).to eq(true)
      end

      let(:testing_method) { [:update_bcache, caching_device, options] }

      include_examples "update previous caching"
    end

    it "sets the given cache mode" do
      expect(device.cache_mode).to_not eq(options[:cache_mode])

      subject.update_bcache(caching_device, options)

      expect(device.cache_mode).to eq(options[:cache_mode])
    end

    context "when a caching device is given" do
      let(:caching_device) { Y2Storage::BcacheCset.all(current_graph).first }

      context "and the bcache has no previous caching set" do
        let(:previous_caching_device) { nil }

        it "attaches the given caching device" do
          expect(device.bcache_cset).to be_nil

          subject.update_bcache(caching_device, options)

          expect(device.bcache_cset).to eq(caching_device)
        end
      end

      context "and the bcache is already associated to the given caching set" do
        let(:previous_caching_device) { caching_device }

        it "does not change the caching set" do
          expect(device.bcache_cset).to eq(previous_caching_device)

          subject.update_bcache(caching_device, options)

          expect(device.bcache_cset).to eq(previous_caching_device)
        end
      end

      context "and the bcache is already associated to another caching set" do
        let(:previous_caching_device) { current_graph.find_by_name("/dev/sda1") }

        it "attaches the given caching device" do
          expect(device.bcache_cset).to eq(previous_caching_device.in_bcache_cset)

          subject.update_bcache(caching_device, options)

          expect(device.bcache_cset).to eq(caching_device)
        end

        include_examples "detach actions"
      end
    end

    context "when a caching device is not given" do
      let(:caching_device) { nil }

      context "and the bcache has already a previous caching set" do
        let(:previous_caching_device) { Y2Storage::BcacheCset.all(current_graph).first }

        include_examples "detach actions"
      end
    end
  end

  describe "#delete_bcache" do
    let(:scenario) { "bcache2.xml" }

    before do
      described_class.new.create_bcache(backing_device, previous_caching_device, {})
    end

    let(:device) { current_graph.find_by_name("/dev/bcache3") }

    let(:backing_device) { current_graph.find_by_name("/dev/sda3") }

    let(:previous_caching_device) { nil }

    it "deletes the bcache device" do
      expect(current_graph.find_by_name("/dev/bcache3")).to_not be_nil

      subject.delete_bcache

      expect(current_graph.find_by_name("/dev/bcache3")).to be_nil
    end

    it "restores the previous status of the backing device" do
      backing_device = device.backing_device

      expect(backing_device.filesystem).to be_nil

      subject.delete_bcache

      expect(backing_device.filesystem).to_not be_nil
    end

    context "when the bcache has an associated caching set" do
      let(:testing_method) { [:delete_bcache] }

      include_examples "update previous caching"
    end
  end

  describe "#committed_bcache?" do
    let(:scenario) { "bcache2.xml" }

    context "when the bcache exists on disk" do
      let(:device) { current_graph.find_by_name("/dev/bcache0") }

      it "returns true" do
        expect(subject.committed_bcache?).to eq(true)
      end
    end

    context "when the bcache does not exist on disk" do
      before do
        sdb1 = current_graph.find_by_name("/dev/sdb1")
        sdb1.create_bcache("/dev/bcache99")
      end

      let(:device) { current_graph.find_by_name("/dev/bcache99") }

      it "returns false" do
        expect(subject.committed_bcache?).to eq(false)
      end
    end
  end

  describe "#committed_bcache_cset?" do
    let(:scenario) { "bcache1.xml" }

    let(:system_graph) { Y2Partitioner::DeviceGraphs.instance.system }

    let(:system_device) { system_graph.find_by_name(device.name) }

    context "when the bcache exists on disk" do
      let(:device) { current_graph.find_by_name("/dev/bcache0") }

      context "and currently it has a caching set" do
        before do
          expect(device.bcache_cset).to_not be_nil
        end

        context "but it does not have a caching set on disk" do
          before do
            system_device.remove_bcache_cset
          end

          it "returns false" do
            expect(subject.committed_bcache_cset?).to eq(false)
          end
        end

        context "and it has a caching set on disk" do
          before do
            expect(system_device.bcache_cset).to_not be_nil
          end

          it "returns true" do
            expect(subject.committed_bcache_cset?).to eq(true)
          end
        end
      end

      context "and currently it does not have a caching set" do
        before do
          device.remove_bcache_cset
        end

        context "and it does not have a caching set on disk" do
          before do
            system_device.remove_bcache_cset
          end

          it "returns false" do
            expect(subject.committed_bcache_cset?).to eq(false)
          end
        end

        context "but it has a caching set on disk" do
          before do
            expect(system_device.bcache_cset).to_not be_nil
          end

          it "returns true" do
            expect(subject.committed_bcache_cset?).to eq(true)
          end
        end
      end
    end

    context "when the bcache does not exist on disk" do
      before do
        sdb1 = current_graph.find_by_name("/dev/vda1")
        sdb1.create_bcache("/dev/bcache99")
      end

      let(:device) { current_graph.find_by_name("/dev/bcache99") }

      it "returns false" do
        expect(subject.committed_bcache_cset?).to eq(false)
      end
    end
  end

  describe "#single_committed_bcache_cset" do
    let(:scenario) { "bcache1.xml" }

    let(:system_graph) { Y2Partitioner::DeviceGraphs.instance.system }

    let(:system_device) { system_graph.find_by_name(device.name) }

    def bcache_cset_only_for(bcache)
      bcache.bcache_cset.bcaches.each do |dev|
        dev.remove_bcache_cset if dev != bcache
      end
    end

    shared_examples "caching set usage" do
      context "and its caching set is used only by this bcache on disk" do
        before do
          bcache_cset_only_for(system_device)
        end

        it "returns true" do
          expect(subject.single_committed_bcache_cset?).to eq(true)
        end
      end

      context "and its caching set is used by several bcaches on disk" do
        before do
          expect(system_device.bcache_cset.bcaches.size).to be > 1
        end

        it "returns false" do
          expect(subject.single_committed_bcache_cset?).to eq(false)
        end
      end
    end

    context "when the bcache exists on disk" do
      let(:device) { current_graph.find_by_name("/dev/bcache0") }

      context "and currently it has a caching set" do
        before do
          expect(device.bcache_cset).to_not be_nil
        end

        context "but it does not have a caching set on disk" do
          before do
            system_device.remove_bcache_cset
          end

          it "returns false" do
            expect(subject.single_committed_bcache_cset?).to eq(false)
          end
        end

        context "and it has a caching set on disk" do
          before do
            expect(system_device.bcache_cset).to_not be_nil
          end

          include_examples "caching set usage"
        end
      end

      context "and currently it does not have a caching set" do
        before do
          device.remove_bcache_cset
        end

        context "and it does not have a caching set on disk" do
          before do
            system_device.remove_bcache_cset
          end

          it "returns false" do
            expect(subject.single_committed_bcache_cset?).to eq(false)
          end
        end

        context "but it has a caching set on disk" do
          before do
            expect(system_device.bcache_cset).to_not be_nil
          end

          include_examples "caching set usage"
        end
      end
    end

    context "when the bcache does not exist on disk" do
      before do
        sdb1 = current_graph.find_by_name("/dev/vda1")
        sdb1.create_bcache("/dev/bcache99")
      end

      let(:device) { current_graph.find_by_name("/dev/bcache99") }

      it "returns false" do
        expect(subject.single_committed_bcache_cset?).to eq(false)
      end
    end
  end
end
