#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

describe Y2Storage::ExistingFilesystem do

  let(:device_name) { "/dev/sdz" }
  subject(:filesystem) { described_class.new(device_name) }

  before do
    allow(filesystem).to receive(:system).and_return true
  end

  describe "#mount_and_check" do
    it "mounts the device" do
      expect(filesystem).to receive(:system).with(/\/usr\/bin\/mount #{device_name}/).and_return true
      filesystem.mount_and_check { |_m| true }
    end

    it "executes the passed block with the mount point as argument" do
      expect { |b| filesystem.mount_and_check(&b) }.to yield_with_args("/mnt")
    end

    it "umounts the device" do
      expect(filesystem).to receive(:system).with(/\/usr\/bin\/umount/).and_return true
      filesystem.mount_and_check { |_m| true }
    end

    it "returns the result of the passed block" do
      result = filesystem.mount_and_check { |_m| true }
      expect(result).to eq true
      result = filesystem.mount_and_check { |_m| false }
      expect(result).to eq false
    end

    it "returns nil if mounting fails" do
      allow(filesystem).to receive(:system).with(/\/mount/).and_return false
      result = filesystem.mount_and_check { |_m| true }
      expect(result).to be_nil
    end

    it "returns nil if unmounting fails" do
      allow(filesystem).to receive(:system).with(/\/umount/).and_return false
      result = filesystem.mount_and_check { |_m| true }
      expect(result).to be_nil
    end
  end
end
