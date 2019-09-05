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
  before do
    devicegraph_stub(scenario)
    fs_controller.encrypt = encrypt
  end

  let(:fs_controller) { Y2Partitioner::Actions::Controllers::Filesystem.new(device, "The title") }

  let(:scenario) { "mixed_disks_btrfs" }

  subject(:controller) { described_class.new(fs_controller) }

  let(:device) { Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name) }

  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:dev_name) { "/dev/sda2" }

  let(:default_subvolume) { "" }

  let(:subvolumes) { Y2Storage::SubvolSpecification.fallback_list }

  let(:encrypt) { false }

  describe "#show_dialog?" do
    context "when the currently editing device has a filesystem that existed previously" do
      it "returns false" do
        expect(subject.show_dialog?).to eq(false)
      end
    end

    context "when the currently editing device does not have a filesystem that existed previously" do
      before do
        allow(device).to receive(:encrypted?).and_return(encrypted)
        allow(device).to receive(:encryption).and_return(encryption)
        allow(device).to receive(:filesystem).and_return(filesystem)
        allow(fs_controller).to receive(:blk_device).and_return(device)
      end

      let(:encrypted) { false }
      let(:encryption) { nil }
      let(:filesystem) { nil }

      context "and the device has not been marked to encrypt" do
        let(:encrypt) { false }

        it "returns false" do
          expect(subject.show_dialog?).to eq(false)
        end
      end

      context "and the device has been marked to encrypt" do
        let(:encrypt) { true }

        context "and the device is currently encrypted" do
          let(:encrypted) { true }
          let(:encryption) { double("Encryption", password: "123456", active?: true) }

          before do
            allow(encryption).to receive(:exists_in_devicegraph?).and_return in_system
          end

          context "with a preexisting encryption" do
            let(:in_system) { true }

            it "returns true" do
              expect(subject.show_dialog?).to eq(true)
            end
          end

          context "with a new encryption" do
            let(:in_system) { false }

            it "returns true" do
              expect(subject.show_dialog?).to eq(true)
            end
          end
        end

        context "and the device is not currently encrypted" do
          let(:encrypted) { false }

          it "returns true" do
            expect(subject.show_dialog?).to eq(true)
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
      let(:scenario) { "logical_encrypted" }

      before { controller.password = password }

      let(:encrypt) { false }
      let(:password) { "12345678" }

      context "and the device was already encrypted at startup" do
        let(:dev_name) { "/dev/sda6" }

        context "and it is marked to be encrypted" do
          let(:encrypt) { true }

          before { controller.action = action }

          context "and the existing encryption must be kept" do
            let(:action) { :keep }

            it "preserves the existing encryption" do
              sid = fs_controller.blk_device.encryption.sid
              subject.finish
              expect(fs_controller.blk_device.encryption.sid).to eq sid
            end

            it "does not change the encryption password" do
              orig_password = fs_controller.blk_device.encryption.password

              subject.finish

              expect(fs_controller.blk_device.encryption.password).to eq orig_password
              expect(fs_controller.blk_device.encryption.password).to_not eq password
            end
          end

          context "and the device must be re-encrypted" do
            let(:action) { :encrypt }

            it "encrypts the device, replacing the previous encryption" do
              sid = fs_controller.blk_device.encryption.sid
              expect(fs_controller.blk_device.encryption.password).to_not eq password

              subject.finish
              expect(fs_controller.blk_device.encryption.sid).to_not eq sid
              expect(fs_controller.blk_device.encryption.password).to eq password
            end
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

      context "and the device was encrypted with the Partitioner" do
        let(:dev_name) { "/dev/sda8" }

        before do
          encryption = device.create_encryption("foo")
          encryption.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
        end

        context "and it is marked to be encrypted" do
          let(:encrypt) { true }

          it "modifies the encryption password" do
            sid = fs_controller.blk_device.encryption.sid
            expect(fs_controller.blk_device.encryption.password).to_not eq password

            subject.finish

            expect(fs_controller.blk_device.encryption.sid).to eq sid
            expect(fs_controller.blk_device.encryption.password).to eq password
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
        let(:dev_name) { "/dev/sda5" }

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
      let(:password) { "12345678" }

      before do
        allow(subject).to receive(:password).and_return(password)
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

  describe "#wizard_title" do
    let(:scenario) { "logical_encrypted" }
    let(:encrypt) { true }

    context "when the current encryption layer was already there at startup" do
      let(:dev_name) { "/dev/sda6" }

      it "returns the expected text" do
        expect(controller.wizard_title).to include "Encryption for "
      end
    end

    context "when the current encryption layer was created by the Partitioner" do
      let(:dev_name) { "/dev/sda8" }

      before do
        encryption = device.create_encryption("foo")
        encryption.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
      end

      it "returns the expected text" do
        expect(controller.wizard_title).to include "Modify encryption "
      end
    end

    context "when the device is currently not encrypted" do
      let(:dev_name) { "/dev/sda5" }

      it "returns the expected text" do
        expect(controller.wizard_title).to include "Encrypt "
      end
    end
  end
end
