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

require "y2storage/proposal_settings"
require "y2storage/partition_tables/type"
require "y2storage/filesystems/type"

RSpec.shared_context "boot requirements" do
  def find_vol(mount_point, volumes)
    volumes.find { |p| p.mount_point == mount_point }
  end

  subject(:checker) { described_class.new(devicegraph) }

  let(:storage_arch) { instance_double("::Storage::Arch") }
  let(:devicegraph) { double("Y2Storage::Devicegraph") }
  let(:dev_sda) { double("Y2Storage::Disk", name: "/dev/sda") }
  let(:dev_sdb) { double("Y2Storage::Disk", name: "/dev/sdb") }

  let(:boot_disk) { dev_sda }
  let(:analyzer) do
    double(
      "Y2Storage::BootRequirementsStrategies::Analyzer",
      boot_disk:       boot_disk,
      root_in_lvm?:    use_lvm,
      encrypted_root?: use_encryption,
      btrfs_root?:     use_btrfs
    )
  end

  let(:use_lvm) { false }
  let(:use_encryption) { false }
  let(:use_btrfs) { true }
  let(:boot_ptable_type) { :msdos }

  before do
    Y2Storage::StorageManager.create_test_instance
    allow(Y2Storage::StorageManager.instance).to receive(:arch).and_return(storage_arch)
    allow(Y2Storage::BootRequirementsStrategies::Analyzer).to receive(:new).and_return(analyzer)

    allow(storage_arch).to receive(:x86?).and_return(architecture == :x86)
    allow(storage_arch).to receive(:ppc?).and_return(architecture == :ppc)
    allow(storage_arch).to receive(:s390?).and_return(architecture == :s390)

    allow(devicegraph).to receive(:disks).and_return [dev_sda, dev_sdb]

    allow(analyzer).to receive(:boot_ptable_type?) { |type| type == boot_ptable_type }
  end
end
