#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016-2019] SUSE LLC
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

RSpec.shared_examples "Mount and umount actions" do
  it "mounts the device" do
    expect(Yast::Execute).to receive(:locally!).with(*mount_cmd)
    subject.send(tested_method)
  end

  it "umounts the device" do
    expect(Yast::Execute).to receive(:locally!).with(*umount_cmd)
    subject.send(tested_method)
  end

  let(:cheetah_error) { Cheetah::ExecutionFailed.new([], "", nil, nil) }

  context "when mount fails" do
    before do
      allow(Yast::Execute).to receive(:locally!).with(*mount_cmd)
        .and_raise(cheetah_error)
    end

    it "does not perform the corresponding action" do
      expect(subject).to_not receive("read_#{tested_method}")
      subject.send(tested_method)
    end

    it "returns nil (or false for boolean methods)" do
      expect(subject.send(tested_method)).to eq result_if_mount_fails
    end
  end

  context "when umount fails" do
    before do
      allow(Yast::Execute).to receive(:locally!).with(*umount_cmd)
        .and_raise(cheetah_error)
    end

    it "sets the value correctly" do
      expect(subject.send(tested_method)).to_not be_nil
    end
  end
end

describe Y2Storage::ExistingFilesystem do
  before do
    fake_scenario(scenario)

    allow(File).to receive(:exist?)
    allow(Yast::Execute).to receive(:locally!)
    allow_any_instance_of(Y2Storage::ELFArch).to receive(:value)

    allow(filesystem).to receive(:detect_content_info).and_return(content_info)
  end

  subject { described_class.new(filesystem, root, mount_point) }

  let(:root) { "" }

  let(:mount_point) { "" }

  let(:mount_cmd) { ["/usr/bin/mount", "-o", "ro", device.name, mount_point] }

  let(:umount_cmd) { ["/usr/bin/umount", "-R", mount_point] }

  let(:result_if_mount_fails) { nil }

  let(:device) { fake_devicegraph.find_by_name(device_name) }

  let(:filesystem) { device.filesystem }

  let(:content_info) { instance_double(Storage::ContentInfo, windows?: windows_content) }

  let(:windows_content) { false }

  let(:scenario) { "windows-linux-free-pc" }

  let(:device_name) { "/dev/sda3" }

  describe "#device" do
    it "returns the device of the filesystem" do
      expect(subject.device).to eq(device)
    end
  end

  describe "#release_name" do
    context "when the filesystem contains a Windows system" do
      let(:device_name) { "/dev/sda1" }

      let(:windows_content) { true }

      it "returns nil" do
        expect(subject.release_name).to be_nil
      end
    end

    context "when the filesystem does not contain a Windows system" do
      let(:device_name) { "/dev/sda3" }

      before do
        allow(Yast::OSRelease).to receive(:ReleaseName).and_return release_name
      end

      let(:release_name) { "Open SUSE" }

      let(:tested_method) { :release_name }

      include_examples "Mount and umount actions"

      context "when there is an installed system" do
        let(:release_name) { "Open SUSE" }

        it "returns the release name" do
          expect(subject.release_name).to eq(release_name)
        end
      end

      context "when there is not an installed system" do
        let(:release_name) { "" }

        it "returns nil" do
          expect(subject.release_name).to be_nil
        end
      end
    end
  end

  describe "#fstab" do
    context "when the filesystem contains a Windows system" do
      let(:device_name) { "/dev/sda1" }

      let(:windows_content) { true }

      it "returns nil" do
        expect(subject.fstab).to be_nil
      end
    end

    context "when the filesystem does not contain a Windows system" do
      let(:device_name) { "/dev/sda3" }

      let(:tested_method) { :fstab }

      before do
        allow(File).to receive(:exist?).and_return(exists_fstab)
      end

      let(:exists_fstab) { true }

      include_examples "Mount and umount actions"

      context "when the fstab file does not exist" do
        let(:exists_fstab) { false }

        it "returns nil" do
          expect(subject.fstab).to be_nil
        end
      end

      context "when the fstab file exists" do
        let(:exists_fstab) { true }

        it "returns the fstab" do
          expect(subject.fstab).to be_a(Y2Storage::Fstab)
        end
      end
    end
  end

  describe "#crypttab" do
    context "when the filesystem contains a Windows system" do
      let(:device_name) { "/dev/sda1" }

      let(:windows_content) { true }

      it "returns nil" do
        expect(subject.crypttab).to be_nil
      end
    end

    context "when the filesystem does not contain a Windows system" do
      let(:device_name) { "/dev/sda3" }

      let(:tested_method) { :crypttab }

      before do
        allow(File).to receive(:exist?).and_return(exists_crypttab)
      end

      let(:exists_crypttab) { true }

      include_examples "Mount and umount actions"

      context "when the crypttab file does not exist" do
        let(:exists_crypttab) { false }

        it "returns nil" do
          expect(subject.crypttab).to be_nil
        end
      end

      context "when the crypttab file exists" do
        let(:exists_crypttab) { true }

        it "returns the crypttab" do
          expect(subject.crypttab).to be_a(Y2Storage::Crypttab)
        end
      end
    end
  end

  describe "#rpi_boot?" do
    context "when the filesystem contains a Windows system" do
      let(:device_name) { "/dev/sda1" }

      let(:windows_content) { true }

      it "returns false" do
        expect(subject.rpi_boot?).to eq(false)
      end
    end

    context "when the filesystem does not contain a Windows system" do
      let(:device_name) { "/dev/sda3" }

      let(:tested_method) { :rpi_boot? }
      let(:existing_files) { [] }
      let(:result_if_mount_fails) { false }

      before do
        allow(File).to receive(:exist?) do |name|
          existing_files.include?(name)
        end
      end

      include_examples "Mount and umount actions"

      context "when there is no file called bootcode.bin or BOOTCODE.bin" do
        let(:existing_files) { %w(/foo /bar) }

        it "returns false" do
          expect(subject.rpi_boot?).to eq false
        end
      end

      context "when there is a file called bootcode.bin" do
        let(:existing_files) { %w(/foo /bar /bootcode.bin) }

        it "returns true" do
          expect(subject.rpi_boot?).to eq true
        end
      end

      context "when there is a file called BOOTCODE.BIN" do
        let(:existing_files) { %w(/BOOTCODE.BIN) }

        it "returns true" do
          expect(subject.rpi_boot?).to eq true
        end
      end
    end
  end

  describe "#windows?" do
    context "when the architecture is not supported for Windows (non-PC system)" do
      let(:architecture) { :s390 }

      it "returns false" do
        expect(subject.windows?).to eq(false)
      end
    end

    context "when the architecture is supported for Windows (PC system)" do
      let(:architecture) { :x86_64 }

      context "and the filesystem is created over a non-suitable Windows partition" do
        let(:device_name) { "/dev/sda3" }

        it "returns false" do
          expect(subject.windows?).to eq(false)
        end
      end

      context "when the filesystem is created over a suitable Windows partition" do
        let(:device_name) { "/dev/sda1" }

        context "and the filesystem contains a Windows system" do
          let(:windows_content) { true }

          it "returns true" do
            expect(subject.windows?).to eq(true)
          end
        end

        context "and the filesystem does not contain a Windows system" do
          let(:windows_content) { false }

          it "returns false" do
            expect(subject.windows?).to eq(false)
          end
        end

        context "and the filesystem content cannot be inspected" do
          before do
            allow(filesystem).to receive(:detect_content_info).and_raise(Storage::Exception)
          end

          it "returns false" do
            expect(subject.windows?).to eq(false)
          end
        end
      end
    end
  end

  describe "#elf_arch" do
    context "when the filesystem contains a Windows system" do
      let(:device_name) { "/dev/sda1" }

      let(:windows_content) { true }

      it "returns nil" do
        expect(subject.elf_arch).to be_nil
      end
    end

    context "when the filesystem does not contain a Windows system" do
      let(:device_name) { "/dev/sda3" }

      before do
        allow_any_instance_of(Y2Storage::ELFArch).to receive(:value).and_return(elf_arch)
      end

      let(:elf_arch) { "x86_64" }

      let(:tested_method) { :elf_arch }

      include_examples "Mount and umount actions"

      it "returns the ELF architecture" do
        expect(subject.elf_arch).to eq(elf_arch)
      end
    end
  end

  describe "#incomplete_installation?" do
    context "when the filesystem contains a Windows system" do
      let(:device_name) { "/dev/sda1" }

      let(:windows_content) { true }

      it "returns false" do
        expect(subject.incomplete_installation?).to eq(false)
      end
    end

    context "when the filesystem does not contain a Windows system" do
      let(:device_name) { "/dev/sda3" }

      before do
        allow(File).to receive(:exist?).with(/runme_at_boot/).and_return(exist_file)
      end

      let(:exist_file) { false }

      let(:tested_method) { :incomplete_installation? }

      let(:result_if_mount_fails) { false }

      include_examples "Mount and umount actions"

      context "when 'runme_at_boot' file exists" do
        let(:exist_file) { true }

        it "returns true" do
          expect(subject.incomplete_installation?).to eq(true)
        end
      end

      context "when 'runme_at_boot' file does not exist" do
        let(:exist_file) { false }

        it "returns false" do
          expect(subject.incomplete_installation?).to eq(false)
        end
      end
    end
  end
end
