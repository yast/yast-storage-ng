#!/usr/bin/env rspec

# Copyright (c) [2020] SUSE LLC
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

require_relative "../spec_helper"
require "y2storage"

describe Y2Storage::BtrfsReader do
  using Y2Storage::Refinements::SizeCasts

  subject(:reader) { described_class.new(filesystem) }

  let(:uuid) { "6f43957a-1298-4c7c-900c-105d37d200b4" }
  let(:filesystem) do
    instance_double(Y2Storage::Filesystems::Btrfs, uuid: "6f43957a-1298-4c7c-900c-105d37d200b4")
  end

  let(:qgroups_list) do
    "qgroupid         rfer         excl     max_rfer     max_excl \n" \
    "--------         ----         ----     --------     -------- \n" \
    "0/264        55.32MiB     55.32MiB      3.00GiB      2.00GiB \n"
  end

  before do
    allow(Yast::Execute).to receive(:locally!).with(including("/usr/bin/mount"))
    allow(Yast::Execute).to receive(:locally!).with(including("/usr/bin/umount"))
    allow(Yast::Execute).to receive(:locally!).with(
      including("/usr/sbin/btrfs"), any_args
    ).and_return([qgroups_list, "", 0])
  end

  describe "#quotas?" do
    subject(:reader) { described_class.new(filesystem) }

    let(:uuid) { "6f43957a-1298-4c7c-900c-105d37d200b4" }

    let(:filesystem) do
      instance_double(Y2Storage::Filesystems::Btrfs, uuid: "6f43957a-1298-4c7c-900c-105d37d200b4")
    end

    let(:qgroups_list) do
      "qgroupid         rfer         excl     max_rfer     max_excl \n" \
      "--------         ----         ----     --------     -------- \n" \
      "0/264        55.32MiB     55.32MiB      3.00GiB      2.00GiB \n"
    end

    it "reports the quotas to be enabled" do
      expect(reader.quotas?).to eq(true)
    end

    context "when quotas are disabled" do
      before do
        allow(Yast::Execute).to receive(:on_target).with(/btrfs/, "qgroup", any_args)

        allow(Yast::Execute).to receive(:locally!).with(
          including("/usr/sbin/btrfs"), any_args
        ).and_return(["", "ERROR: can't list qgroups", 1])
      end

      it "returns nil" do
        expect(reader.quotas?).to eq(false)
      end
    end

    context "when qgroups are not in sync" do
      before do
        allow(Yast::Execute).to receive(:locally!).with(
          including("/usr/sbin/btrfs"), any_args
        ).and_return(["", "WARNING: qgroup data inconsistent", 1])
      end

      it "reports the quotas to be enabled" do
        expect(reader.quotas?).to eq(true)
      end
    end
  end

  describe "#qgroups" do
    it "returns the qgroups" do
      qgroups = reader.qgroups
      expect(qgroups.first.rfer_limit).to eq(3.GiB)
      expect(qgroups.first.excl_limit).to eq(2.GiB)
    end
  end
end
