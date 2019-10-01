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

  describe ".initialize" do
    let(:scenario) { "encrypted_random_swap.xml" }

    context "when the device is not encrypted" do
      let(:dev_name) { "/dev/vda2" }

      it "assigns the default encryption method" do
        expect(subject.method.is?(:luks1)).to eq(true)
      end
    end

    context "when the device is encrypted" do
      # Swap with random key
      let(:dev_name) { "/dev/vda3" }

      context "and the current encryption method is a valid option" do
        it "assigns the current encryption method" do
          expect(subject.method.is?(:random_swap)).to eq(true)
        end
      end

      context "and the current encryption method is not a valid option" do
        # Swap with random key
        let(:dev_name) { "/dev/vda3" }

        before do
          # It is no consider a swap device anymore
          device.filesystem.mount_path = "/foo"
        end

        it "assigns the default encryption method" do
          expect(subject.method.is?(:luks1)).to eq(true)
        end
      end
    end
  end

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
          let(:method) { Y2Storage::EncryptionMethod::RANDOM_SWAP }
          let(:encryption) { double("Encryption", method: method, password: "123456", active?: true) }

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

  describe "#actions" do
    let(:scenario) { "encrypted_random_swap.xml" }

    context "when the option to encrypt the device was selected" do
      let(:encrypt) { true }

      context "and the device is not encrypted" do
        let(:dev_name) { "/dev/vda2" }

        it "returns :encrypt action" do
          expect(subject.actions).to contain_exactly(:encrypt)
        end
      end

      context "and the device is encrypted" do
        context "and the current encryption exists on disk" do
          # Encrypted swap with random key
          let(:dev_name) { "/dev/vda3" }

          context "and the existing encryption can be used for the current device" do
            before do
              allow_any_instance_of(Y2Storage::Encryption).to receive(:active?).and_return(active)
            end

            context "and the existing encryption is active" do
              let(:active) { true }

              it "returns :keep and :encrypt actions" do
                expect(subject.actions).to contain_exactly(:keep, :encrypt)
              end
            end

            context "and the existing encryption is not active" do
              let(:active) { false }

              it "returns :encrypt action" do
                expect(subject.actions).to contain_exactly(:encrypt)
              end
            end
          end

          context "and the existing encryption cannot be used for the current device" do
            context "and the current filesystem already exists on disk" do
              before do
                # The device is not a swap anymore
                device.encryption.filesystem.mount_path = "/foo"
              end

              it "returns :sanitize action" do
                expect(subject.actions).to contain_exactly(:sanitize)
              end
            end

            context "and the current filesystem does not exist on disk yet" do
              before do
                device.encryption.delete_filesystem
                device.encryption.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
              end

              it "returns :encrypt action" do
                expect(subject.actions).to contain_exactly(:encrypt)
              end
            end

            context "and the encryption is not currently formatted" do
              before do
                device.encryption.delete_filesystem
              end

              it "returns :encrypt action" do
                expect(subject.actions).to contain_exactly(:encrypt)
              end
            end
          end
        end
      end

      context "when the option to encrypt the device was not selected" do
        let(:encrypt) { false }

        let(:dev_name) { "/dev/vda2" }

        it "returns :remove action" do
          expect(subject.actions).to contain_exactly(:remove)
        end
      end
    end
  end

  describe "#methods" do
    let(:scenario) { "mixed_disks" }

    let(:dev_name) { "/dev/sda1" }

    it "returns a collection of encryption methods" do
      expect(subject.methods).to be_a Array
      expect(subject.methods.first).to be_a Y2Storage::EncryptionMethod
    end

    shared_context "double methods" do
      let(:method_only_for_swap) { instance_double(Y2Storage::EncryptionMethod, only_for_swap?: true) }

      let(:another_method) { instance_double(Y2Storage::EncryptionMethod, only_for_swap?: false) }

      let(:encryption_methods) { [method_only_for_swap, another_method] }

      before do
        allow(Y2Storage::EncryptionMethod).to receive(:available).and_return(encryption_methods)
      end
    end

    context "when working with a swap filesystem" do
      include_context "double methods"

      let(:dev_name) { "/dev/sdb1" }

      it "includes the encryption methods intented to be used only with swap" do
        expect(subject.methods).to include(method_only_for_swap)
      end
    end

    context "when not working with a swap filesystem" do
      include_context "double methods"

      let(:dev_name) { "/dev/sdb1" }

      before do
        device.filesystem.mount_path = "/foo"
      end

      it "does not includes the encryption methods intented to be used only with swap" do
        expect(subject.methods).to_not include(method_only_for_swap)
      end
    end
  end

  describe "#several_encrypt_methods?" do
    before do
      allow(subject).to receive(:methods).and_return(methods)
    end

    context "when more than one encryption methods are available" do
      let(:methods) { [double, double] }

      it "returns true" do
        expect(subject.several_encrypt_methods?).to eq(true)
      end
    end

    context "when there is only one encryption method available" do
      let(:methods) { [double] }

      it "returns false" do
        expect(subject.several_encrypt_methods?).to eq(false)
      end
    end
  end

  describe "#finish" do
    context "when the encryption should be sanitized" do
      let(:scenario) { "encrypted_random_swap.xml" }

      # Encrypted swap with random key
      let(:dev_name) { "/dev/vda3" }

      before do
        subject.action = :sanitize

        # The device is not a swap anymore
        device.encryption.filesystem.mount_path = "/foo"
      end

      context "and the current filesystem exists on disk" do
        it "removes the encryption device and the filesystem" do
          subject.finish

          expect(fs_controller.blk_device.encrypted?).to eq(false)
        end
      end

      context "and the current filesystem does no exist on disk" do
        before do
          encryption = device.encryption

          encryption.remove_descendants
          encryption.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
        end

        it "removes the encryption layer" do
          subject.finish

          expect(fs_controller.blk_device.encrypted?).to eq(false)
        end

        it "preserves the filesystem" do
          subject.finish

          expect(fs_controller.blk_device.formatted?).to eq(true)
          expect(fs_controller.blk_device.filesystem.type.is?(:ext4)).to eq(true)
        end
      end

      context "and the encryption is not currently formatted" do
        before do
          device.encryption.delete_filesystem
        end

        it "removes the encryption layer" do
          subject.finish

          expect(fs_controller.blk_device.encrypted?).to eq(false)
        end
      end
    end

    context "when it is not possible to change the encrypt" do
      before do
        allow(subject).to receive(:can_change_encrypt?).and_return(can_change_encrypt)
      end

      let(:can_change_encrypt) { false }

      it "does nothing" do
        devicegraph = Y2Partitioner::DeviceGraphs.instance.current.dup
        subject.finish

        expect(devicegraph).to eq(Y2Partitioner::DeviceGraphs.instance.current)
      end
    end

    context "when it is possible to change the encrypt" do
      before do
        allow(subject).to receive(:can_change_encrypt?).and_return(can_change_encrypt)
      end

      let(:scenario) { "logical_encrypted" }
      let(:can_change_encrypt) { true }
      let(:password) { "12345678" }
      let(:method) { Y2Storage::EncryptionMethod::LUKS1 }

      before do
        controller.method = method
        controller.action = action
        controller.password = password
      end

      context "and the device was already encrypted at startup" do
        let(:encrypt) { true }
        let(:dev_name) { "/dev/sda6" }

        context "but the existing encryption must be kept" do
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

        context "but the device must be re-encrypted" do
          let(:action) { :encrypt }

          it "encrypts the device, replacing the previous encryption" do
            sid = fs_controller.blk_device.encryption.sid
            subject.finish
            expect(fs_controller.blk_device.encryption.sid).to_not eq sid
          end
        end

        context "but the encryption was marked to be removed" do
          let(:encrypt) { false }
          let(:action) { :remove }

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
          let(:action) { :encrypt }

          it "modifies the encryption password" do
            expect(fs_controller.blk_device.encryption.password).to_not eq password
            subject.finish
            expect(fs_controller.blk_device.encryption.password).to eq password
          end
        end

        context "and it is not marked to be encrypted" do
          let(:encrypt) { false }
          let(:action) { :remove }

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
          let(:action) { :encrypt }

          it "encrypts the device" do
            subject.finish
            expect(fs_controller.blk_device.encryption).to_not be_nil
            expect(fs_controller.blk_device.encryption.password).to eq(password)
          end
        end

        context "and it is not marked to be encrypted" do
          let(:encrypt) { false }
          let(:action) { :remove }

          it "does nothing" do
            devicegraph = Y2Partitioner::DeviceGraphs.instance.current.dup
            subject.finish

            expect(devicegraph).to eq(Y2Partitioner::DeviceGraphs.instance.current)
          end
        end
      end
    end

    context "when the device has an unused LvmPv" do
      before do
        allow(subject).to receive(:can_change_encrypt?).and_return(can_change_encrypt)
      end

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
