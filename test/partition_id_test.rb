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

describe Y2Storage::PartitionId do
  describe ".linux_system_ids" do
    it "returns an array of ids" do
      expect(described_class.linux_system_ids).to be_a Array
      expect(described_class.linux_system_ids).to all(be_a(Y2Storage::PartitionId))
    end

    it "does not allow to alter the original list" do
      size = described_class.linux_system_ids.size
      ids = described_class.linux_system_ids
      ids << Y2Storage::PartitionId::NTFS

      expect(ids.size).to eq(size + 1)
      expect(described_class.linux_system_ids.size).to eq size
    end
  end

  describe ".windows_system_ids" do
    it "returns an array of ids" do
      expect(described_class.windows_system_ids).to be_a Array
      expect(described_class.windows_system_ids).to all(be_a(Y2Storage::PartitionId))
    end

    it "does not allow to alter the original list" do
      size = described_class.windows_system_ids.size
      ids = described_class.windows_system_ids
      ids << Y2Storage::PartitionId::LINUX

      expect(ids.size).to eq(size + 1)
      expect(described_class.windows_system_ids.size).to eq size
    end
  end

  describe ".new_from_legacy" do
    pending
  end

  describe "#to_i_legacy" do
    pending
  end
end
