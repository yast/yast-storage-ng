#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016-2017] SUSE LLC
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
    expect(subject).to receive(:system).with(mount_cmd).and_return true
    subject.send(tested_method)
  end

  it "umounts the device" do
    expect(subject).to receive(:system).with(umount_cmd).and_return true
    subject.send(tested_method)
  end

  context "when mount fails" do
    before do
      allow(subject).to receive(:system).with(mount_cmd).and_return(false)
    end

    it "does not perform the corresponding action" do
      expect(subject).to_not receive("read_#{tested_method}")
      subject.send(tested_method)
    end

    it "returns nil" do
      expect(subject.send(tested_method)).to be_nil
    end
  end

  context "when umount fails" do
    before do
      allow(subject).to receive(:system).with(umount_cmd).and_return(false)
    end

    it "sets the value correctly" do
      expect(subject.send(tested_method)).to_not be_nil
    end
  end
end

describe Y2Storage::ExistingFilesystem do
  subject { described_class.new(filesystem, root, mount_point) }

  let(:root) { "" }
  let(:mount_point) { "" }
  let(:mount_cmd) { Regexp.new("mount -o ro #{device.name}") }
  let(:umount_cmd) { Regexp.new("umount -R") }

  let(:filesystem) { instance_double(Storage::BlkFilesystem, blk_devices: [device]) }
  let(:device) { instance_double(Storage::BlkDevice, name: "/dev/sda") }

  before do
    allow(subject).to receive(:system).and_return true
  end

  describe "#device" do
    it "returns the device of the filesystem" do
      expect(subject.device).to eq(device)
    end
  end

  describe "#release_name" do
    let(:tested_method) { :release_name }

    before do
      allow(Yast::OSRelease).to receive(:ReleaseName).and_return release_name
    end

    let(:release_name) { "Open SUSE" }

    include_examples "Mount and umount actions"

    context "when there is an installed system" do
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

  describe "#fstab" do
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

  describe "#crypttab" do
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
