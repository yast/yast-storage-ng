#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) 2016 SUSE LLC
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
require "storage"
require "y2storage/fake_device_factory"

describe Y2Storage::FakeDeviceFactory do

  it "reads yaml of simple disk and partition setup" do

    environment = Storage::Environment.new(true, Storage::ProbeMode_NONE, Storage::TargetMode_DIRECT)
    storage = Storage::Storage.new(environment)
    staging = storage.staging

    # rubocop:disable Style/StringLiterals

    input = ['---',
             '- disk:',
             '    name: "/dev/sda"',
             '    size: 256 GiB',
             '    block_size: 4 KiB',
             '    partition_table: gpt',
             '    partitions:',
             '    - free:',
             '        size: 1 MiB',
             '        start: 0 B',
             '    - partition:',
             '        size: 0.5 GiB',
             '        start: 1 MiB',
             '        name: "/dev/sda1"',
             '        type: primary',
             '        id: swap',
             '        file_system: swap',
             '        mount_point: swap',
             '    - partition:',
             '        size: 16 GiB',
             '        start: 513 MiB (0.50 GiB)',
             '        name: "/dev/sda2"',
             '        type: primary',
             '        id: linux',
             '        file_system: ext4',
             '        mount_point: "/"',
             '        fstab_options:',
             '        - acl',
             '        - user_xattr',
             '    - free:',
             '        size: 245247 MiB (239.50 GiB)',
             '        start: 16897 MiB (16.50 GiB)']

    # rubocop:enable all

    io = StringIO.new(input.join("\n"))
    Y2Storage::FakeDeviceFactory.load_yaml_file(staging, io)

    expect(staging.num_devices).to eq 6
    expect(staging.num_holders).to eq 5

    sda = Storage.to_disk(Storage::BlkDevice.find_by_name(staging, "/dev/sda"))
    expect(sda.size).to eq 256 * Storage.GiB
    expect(sda.region.block_size).to eq 4 * Storage.KiB

    sda1 = Storage.to_partition(Storage::BlkDevice.find_by_name(staging, "/dev/sda1"))
    expect(sda1.size).to eq 512 * Storage.MiB

    sda2 = Storage.to_partition(Storage::BlkDevice.find_by_name(staging, "/dev/sda2"))
    expect(sda2.size).to eq 16 * Storage.GiB
    expect(sda2.filesystem.fstab_options.to_a).to contain_exactly("acl", "user_xattr")

  end

  it "reads yaml of simple lvm setup" do

    environment = Storage::Environment.new(true, Storage::ProbeMode_NONE, Storage::TargetMode_DIRECT)
    storage = Storage::Storage.new(environment)
    staging = storage.staging

    # rubocop:disable Style/StringLiterals

    input = ['---',
             '- disk:',
             '    name: "/dev/sda"',
             '    size: 1 TiB',
             '    block_size: 0.5 KiB',
             '    io_size: 0 B',
             '    min_grain: 1 MiB',
             '    align_ofs: 0 B',
             '- lvm_vg:',
             '    vg_name: system',
             '    extent_size: 8 MiB',
             '    lvm_lvs:',
             '    - lvm_lv:',
             '        lv_name: root',
             '        size: 16 GiB',
             '        file_system: ext4',
             '        mount_point: "/"',
             '    lvm_pvs:',
             '    - lvm_pv:',
             '        blk_device: "/dev/sda"']

    # rubocop:enable all

    io = StringIO.new(input.join("\n"))
    Y2Storage::FakeDeviceFactory.load_yaml_file(staging, io)

    expect(staging.num_devices).to eq 5
    expect(staging.num_holders).to eq 4

    root = Storage.to_lvm_lv(Storage::BlkDevice.find_by_name(staging, "/dev/system/root"))
    expect(root.lv_name).to eq "root"
    expect(root.size).to eq 16 * Storage.GiB

    system = root.lvm_vg
    expect(system.vg_name).to eq "system"
    expect(system.extent_size).to eq 8 * Storage.MiB
    expect(system.lvm_lvs.size).to eq 1
    expect(system.lvm_pvs.size).to eq 1

  end

  it "reads yaml for a simple encryption setup" do
    environment = Storage::Environment.new(true, Storage::ProbeMode_NONE, Storage::TargetMode_DIRECT)
    storage = Storage::Storage.new(environment)
    staging = storage.staging

    # rubocop:disable Style/StringLiterals

    input = ['---',
             '- disk:',
             '    name: "/dev/sda"',
             '    size: 256 GiB',
             '    block_size: 4 KiB',
             '    partition_table: gpt',
             '    partitions:',
             '    - partition:',
             '        size: 0.5 GiB',
             '        start: 1 MiB',
             '        name: "/dev/sda1"',
             '        type: primary',
             '        id: swap',
             '        file_system: swap',
             '        mount_point: swap',
             '    - partition:',
             '        size: 16 GiB',
             '        start: 513 MiB (0.50 GiB)',
             '        name: "/dev/sda2"',
             '        type: primary',
             '        id: linux',
             '        encryption:',
             '            type: "luks"',
             '            name: "cr_root"',
             '            password: "s3cr3t"',
             '        file_system: ext4',
             '        mount_point: "/"',
             '        fstab_options:',
             '        - acl',
             '        - user_xattr',
             '']

    # rubocop:enable all

    io = StringIO.new(input.join("\n"))
    Y2Storage::FakeDeviceFactory.load_yaml_file(staging, io)

    expect(staging.num_devices).to eq 7
    expect(staging.num_holders).to eq 5
    enc = Storage.to_encryption(Storage::BlkDevice.find_by_name(staging, "/dev/mapper/cr_root"))
    expect(enc.name).to eq "/dev/mapper/cr_root"
    expect(enc.password).to eq "s3cr3t"

  end

end
