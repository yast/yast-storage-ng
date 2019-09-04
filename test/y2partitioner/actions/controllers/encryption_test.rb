#!/usr/bin/env rspec

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
require "y2partitioner/actions/controllers/filesystem"
require "y2partitioner/actions/controllers/encryption"

describe Y2Partitioner::Actions::Controllers::Encryption do
  before { devicegraph_stub(scenario) }

  let(:scenario) { "mixed_disks_btrfs" }

  subject(:controller) { described_class.new(fs_controller) }

  let(:fs_controller) { Y2Partitioner::Actions::Controllers::Filesystem.new(device, "The title") }

  let(:device) { Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name) }

  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:dev_name) { "/dev/sda2" }

  let(:default_subvolume) { "" }

  let(:subvolumes) { Y2Storage::SubvolSpecification.fallback_list }

  describe "#to_be_encrypted?" do
    context "when the currently editing device has a filesystem that existed previously" do
      it "returns false" do
        expect(subject.to_be_encrypted?).to eq(false)
      end
    end

    context "when the currently editing device does not have a filesystem that existed previously" do
      before do
        allow(fs_controller).to receive(:encrypt).and_return(encrypt)
        allow(device).to receive(:encrypted?).and_return(encrypted)
        allow(device).to receive(:filesystem).and_return(filesystem)
        allow(fs_controller).to receive(:blk_device).and_return(device)
      end

      let(:encrypt) { false }
      let(:encrypted) { false }
      let(:filesystem) { nil }

      context "and the device has not been marked to encrypt" do
        let(:encrypt) { false }

        it "returns false" do
          expect(subject.to_be_encrypted?).to eq(false)
        end
      end

      context "and the device has been marked to encrypt" do
        let(:encrypt) { true }

        context "and the device is currently encrypted" do
          let(:encrypted) { true }

          it "returns false" do
            expect(subject.to_be_encrypted?).to eq(false)
          end
        end

        context "and the device is not currently encrypted" do
          let(:encrypted) { false }

          it "returns true" do
            expect(subject.to_be_encrypted?).to eq(true)
          end
        end
      end
    end
  end

  describe "#finish" do
    before do
      allow(subject).to receive(:can_change_encrypt?).and_return(can_change_encrypt)
    end

    context "when it is not possible to change the encrypt" do
      let(:can_change_encrypt) { false }

      it "does nothing" do
        devicegraph = Y2Partitioner::DeviceGraphs.instance.current.dup
        subject.finish

        expect(devicegraph).to eq(Y2Partitioner::DeviceGraphs.instance.current)
      end
    end

    context "when it is possible to change the encrypt" do
      let(:can_change_encrypt) { true }

      before do
        allow(fs_controller).to receive(:encrypt).and_return(encrypt)
        allow(subject).to receive(:encrypt_password).and_return(password)
      end

      let(:encrypt) { false }
      let(:password) { "12345678" }

      context "and the device was already encrypted" do
        before do
          device.remove_descendants
          encryption = device.create_encryption("foo")
          encryption.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
        end

        context "and it is marked to be encrypted" do
          let(:encrypt) { true }

          it "does nothing" do
            devicegraph = Y2Partitioner::DeviceGraphs.instance.current.dup
            subject.finish

            expect(devicegraph).to eq(Y2Partitioner::DeviceGraphs.instance.current)
          end
        end

        context "and it is not marked to be encrypted" do
          let(:encrypt) { false }

          it "removes the encryption" do
            expect(fs_controller.blk_device.encryption).to_not be_nil
            subject.finish
            expect(fs_controller.blk_device.encryption).to be_nil
          end
        end
      end

      context "and the device is not encrypted" do
        context "and it is marked to be encrypted" do
          let(:encrypt) { true }

          it "encrypts the device" do
            subject.finish
            expect(fs_controller.blk_device.encryption).to_not be_nil
            expect(fs_controller.blk_device.encryption.password).to eq(password)
          end
        end

        context "and it is not marked to be encrypted" do
          let(:encrypt) { false }

          it "does nothing" do
            devicegraph = Y2Partitioner::DeviceGraphs.instance.current.dup
            subject.finish

            expect(devicegraph).to eq(Y2Partitioner::DeviceGraphs.instance.current)
          end
        end
      end
    end

    context "when the device has an unused LvmPv" do
      let(:scenario) { "unused_lvm_pvs.xml" }

      let(:can_change_encrypt) { true }
      let(:encrypt) { false }
      let(:password) { "12345678" }

      before do
        allow(fs_controller).to receive(:encrypt).and_return(encrypt)
        allow(subject).to receive(:encrypt_password).and_return(password)
      end

      context "which was not encrypted" do
        let(:dev_name) { "/dev/sda2" }

        context "and it is marked to be encrypted" do
          let(:encrypt) { true }

          it "removes the unused LvmPv" do
            subject.finish
            expect(fs_controller.blk_device.lvm_pv).to be_nil
          end

          it "encrypts the device" do
            subject.finish
            expect(fs_controller.blk_device.encryption).to_not be_nil
            expect(fs_controller.blk_device.encryption.password).to eq(password)
          end
        end

        context "and it is not marked to be encrypted" do
          let(:encrypt) { false }

          it "removes the unused LvmPv" do
            subject.finish
            expect(fs_controller.blk_device.lvm_pv).to be_nil
          end
        end
      end

      context "which was already encrypted" do
        let(:dev_name) { "/dev/sda3" }

        context "and it is marked to keep the encryption" do
          let(:encrypt) { true }

          it "keeps the encryption" do
            encryption = fs_controller.blk_device.encryption
            subject.finish
            expect(fs_controller.blk_device.encryption).to eq(encryption)
          end

          it "removes the unused LvmPv" do
            subject.finish
            expect(fs_controller.blk_device.lvm_pv).to be_nil
          end
        end

        context "and it is not marked to be encrypted" do
          let(:encrypt) { false }

          it "removes the encryption" do
            subject.finish
            expect(fs_controller.blk_device.encryption).to be_nil
          end

          it "removes the unused LvmPv" do
            subject.finish
            expect(fs_controller.blk_device.lvm_pv).to be_nil
          end
        end
      end
    end
  end
end
