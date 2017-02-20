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
require "y2storage/yaml_writer"

describe Y2Storage::YamlWriter do

  it "produces yaml of a simple disk and partition setup" do

    environment = Storage::Environment.new(true, Storage::ProbeMode_NONE, Storage::TargetMode_DIRECT)
    storage = Storage::Storage.new(environment)
    staging = storage.staging

    sda = Storage::Disk.create(staging, "/dev/sda")
    sda.size = 256 * Storage.GiB

    gpt = sda.create_partition_table(Storage::PtType_GPT)

    sda1 = gpt.create_partition("/dev/sda1", Storage::Region.new(2048, 1048576, 512),
      Storage::PartitionType_PRIMARY)
    sda1.id = Storage::ID_SWAP

    swap = sda1.create_filesystem(Storage::FsType_SWAP)
    swap.add_mountpoint("swap")

    sda2 = gpt.create_partition("/dev/sda2", Storage::Region.new(1050624, 33554432, 512),
      Storage::PartitionType_PRIMARY)

    ext4 = sda2.create_filesystem(Storage::FsType_EXT4)
    ext4.add_mountpoint("/")
    ext4.fstab_options << "acl"
    ext4.fstab_options << "user_xattr"

    # rubocop:disable Style/StringLiterals

    result = ['---',
              '- disk:',
              '    name: "/dev/sda"',
              '    size: 256 GiB',
              '    block_size: 0.5 KiB',
              '    io_size: 0 B',
              '    min_grain: 1 MiB',
              '    align_ofs: 0 B',
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

    io = StringIO.new
    Y2Storage::YamlWriter.write(staging, io)
    expect(io.string).to eq result.join("\n") + "\n"

  end

  it "produces yaml of a simple lvm setup" do

    environment = Storage::Environment.new(true, Storage::ProbeMode_NONE, Storage::TargetMode_DIRECT)
    storage = Storage::Storage.new(environment)
    staging = storage.staging

    sda = Storage::Disk.create(staging, "/dev/sda")
    sda.size = 1 * Storage.TiB

    lvm_vg = Storage::LvmVg.create(staging, "system")
    lvm_vg.add_lvm_pv(sda)

    lvm_lv = lvm_vg.create_lvm_lv("root", 16 * Storage.GiB)
    lvm_lv.create_filesystem(Storage::FsType_EXT4)

    # rubocop:disable Style/StringLiterals

    result = ['---',
              '- disk:',
              '    name: "/dev/sda"',
              '    size: 1 TiB',
              '    block_size: 0.5 KiB',
              '    io_size: 0 B',
              '    min_grain: 1 MiB',
              '    align_ofs: 0 B',
              '- lvm_vg:',
              '    vg_name: system',
              '    extent_size: 4 MiB',
              '    lvm_lvs:',
              '    - lvm_lv:',
              '        lv_name: root',
              '        size: 16 GiB',
              '        file_system: ext4',
              '    lvm_pvs:',
              '    - lvm_pv:',
              '        blk_device: "/dev/sda"']

    # rubocop:enable all

    io = StringIO.new
    Y2Storage::YamlWriter.write(staging, io)
    expect(io.string).to eq result.join("\n") + "\n"

  end

  it "produces yaml of an encrypted partition setup" do

    environment = Storage::Environment.new(true, Storage::ProbeMode_NONE, Storage::TargetMode_DIRECT)
    storage = Storage::Storage.new(environment)
    staging = storage.staging

    sda = Storage::Disk.create(staging, "/dev/sda")
    sda.size = 256 * Storage.GiB

    gpt = sda.create_partition_table(Storage::PtType_GPT)

    sda1 = gpt.create_partition("/dev/sda1", Storage::Region.new(2048, 1048576, 512),
      Storage::PartitionType_PRIMARY)
    sda1.id = Storage::ID_SWAP

    swap = sda1.create_filesystem(Storage::FsType_SWAP)
    swap.add_mountpoint("swap")

    sda2 = gpt.create_partition("/dev/sda2", Storage::Region.new(1050624, 33554432, 512),
      Storage::PartitionType_PRIMARY)

    encryption = sda2.create_encryption("cr_system")
    encryption.password = "vry!s3cret"

    ext4 = encryption.create_filesystem(Storage::FsType_EXT4)
    ext4.add_mountpoint("/")
    ext4.fstab_options << "acl"
    ext4.fstab_options << "user_xattr"

    # rubocop:disable Style/StringLiterals

    result = ['---',
              '- disk:',
              '    name: "/dev/sda"',
              '    size: 256 GiB',
              '    block_size: 0.5 KiB',
              '    io_size: 0 B',
              '    min_grain: 1 MiB',
              '    align_ofs: 0 B',
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
              '        encryption:',
              '          type: luks',
              '          name: "/dev/mapper/cr_system"',
              '          password: vry!s3cret',
              '        file_system: ext4',
              '        mount_point: "/"',
              '        fstab_options:',
              '        - acl',
              '        - user_xattr',
              '    - free:',
              '        size: 245247 MiB (239.50 GiB)',
              '        start: 16897 MiB (16.50 GiB)']

    # rubocop:enable all

    io = StringIO.new
    Y2Storage::YamlWriter.write(staging, io)
    expect(io.string).to eq result.join("\n") + "\n"

  end

  it "produces yaml of an lvm setup with encryption on the PV level" do

    environment = Storage::Environment.new(true, Storage::ProbeMode_NONE, Storage::TargetMode_DIRECT)
    storage = Storage::Storage.new(environment)
    staging = storage.staging

    sda = Storage::Disk.create(staging, "/dev/sda")
    sda.size = 256 * Storage.GiB

    ptable = sda.create_partition_table(Storage::PtType_MSDOS)
    blocks = sda.size / 512 - 2048

    sda1 = ptable.create_partition("/dev/sda1", Storage::Region.new(2048, blocks, 512),
      Storage::PartitionType_PRIMARY)
    sda1.id = Storage::ID_LVM

    encryption = sda1.create_encryption("cr_sda1")
    encryption.password = "s3cr3t"

    lvm_vg = Storage::LvmVg.create(staging, "system")
    lvm_vg.add_lvm_pv(encryption)

    lvm_lv = lvm_vg.create_lvm_lv("root", 16 * Storage.GiB)
    fs = lvm_lv.create_filesystem(Storage::FsType_EXT4)
    fs.add_mountpoint("/")

    # rubocop:disable Style/StringLiterals

    result = ['---',
              '- disk:',
              '    name: "/dev/sda"',
              '    size: 256 GiB',
              '    block_size: 0.5 KiB',
              '    io_size: 0 B',
              '    min_grain: 1 MiB',
              '    align_ofs: 0 B',
              '    partition_table: msdos',
              '    mbr_gap: 1 MiB',
              '    partitions:',
              '    - free:',
              '        size: 1 MiB',
              '        start: 0 B',
              '    - partition:',
              '        size: 262143 MiB (256.00 GiB)',
              '        start: 1 MiB',
              '        name: "/dev/sda1"',
              '        type: primary',
              '        id: lvm',
              '        encryption:',
              '          type: luks',
              '          name: "/dev/mapper/cr_sda1"',
              '          password: s3cr3t',
              '- lvm_vg:',
              '    vg_name: system',
              '    extent_size: 4 MiB',
              '    lvm_lvs:',
              '    - lvm_lv:',
              '        lv_name: root',
              '        size: 16 GiB',
              '        file_system: ext4',
              '        mount_point: "/"',
              '    lvm_pvs:',
              '    - lvm_pv:',
              '        blk_device: "/dev/mapper/cr_sda1"']

    # rubocop:enable all

    io = StringIO.new
    Y2Storage::YamlWriter.write(staging, io)
    expect(io.string).to eq result.join("\n") + "\n"

  end

  it "produces yaml of an lvm setup with encryption on the LV level" do

    environment = Storage::Environment.new(true, Storage::ProbeMode_NONE, Storage::TargetMode_DIRECT)
    storage = Storage::Storage.new(environment)
    staging = storage.staging

    sda = Storage::Disk.create(staging, "/dev/sda")
    sda.size = 256 * Storage.GiB

    ptable = sda.create_partition_table(Storage::PtType_MSDOS)
    blocks = sda.size / 512 - 2048

    sda1 = ptable.create_partition("/dev/sda1", Storage::Region.new(2048, blocks, 512),
      Storage::PartitionType_PRIMARY)
    sda1.id = Storage::ID_LVM

    lvm_vg = Storage::LvmVg.create(staging, "system")
    lvm_vg.add_lvm_pv(sda1)

    lvm_lv = lvm_vg.create_lvm_lv("root", 16 * Storage.GiB)

    encryption = lvm_lv.create_encryption("cr_sda1")
    encryption.password = "s3cr3t"

    fs = encryption.create_filesystem(Storage::FsType_XFS)
    fs.add_mountpoint("/")

    # rubocop:disable Style/StringLiterals

    result = ['---',
              '- disk:',
              '    name: "/dev/sda"',
              '    size: 256 GiB',
              '    block_size: 0.5 KiB',
              '    io_size: 0 B',
              '    min_grain: 1 MiB',
              '    align_ofs: 0 B',
              '    partition_table: msdos',
              '    mbr_gap: 1 MiB',
              '    partitions:',
              '    - free:',
              '        size: 1 MiB',
              '        start: 0 B',
              '    - partition:',
              '        size: 262143 MiB (256.00 GiB)',
              '        start: 1 MiB',
              '        name: "/dev/sda1"',
              '        type: primary',
              '        id: lvm',
              '- lvm_vg:',
              '    vg_name: system',
              '    extent_size: 4 MiB',
              '    lvm_lvs:',
              '    - lvm_lv:',
              '        lv_name: root',
              '        size: 16 GiB',
              '        encryption:',
              '          type: luks',
              '          name: "/dev/mapper/cr_sda1"',
              '          password: s3cr3t',
              '        file_system: xfs',
              '        mount_point: "/"',
              '    lvm_pvs:',
              '    - lvm_pv:',
              '        blk_device: "/dev/sda1"']

    # rubocop:enable all

    io = StringIO.new
    Y2Storage::YamlWriter.write(staging, io)
    expect(io.string).to eq result.join("\n") + "\n"

  end

  it "produces yaml of a filesystem directly on a disk without a partition table" do

    environment = Storage::Environment.new(true, Storage::ProbeMode_NONE, Storage::TargetMode_DIRECT)
    storage = Storage::Storage.new(environment)
    staging = storage.staging

    disk = Storage::Disk.create(staging, "/dev/sda")
    disk.size = 256 * Storage.GiB

    fs = disk.create_filesystem(Storage::FsType_XFS)
    fs.add_mountpoint("/data")

    # rubocop:disable Style/StringLiterals

    result = ['---',
              '- disk:',
              '    name: "/dev/sda"',
              '    size: 256 GiB',
              '    block_size: 0.5 KiB',
              '    io_size: 0 B',
              '    min_grain: 1 MiB',
              '    align_ofs: 0 B',
              '    file_system: xfs',
              '    mount_point: "/data"']

    # rubocop:enable all

    io = StringIO.new
    Y2Storage::YamlWriter.write(staging, io)
    # print io.string
    expect(io.string).to eq result.join("\n") + "\n"

  end

  it "produces yaml of an encrypted filesystem directly on a disk" do

    environment = Storage::Environment.new(true, Storage::ProbeMode_NONE, Storage::TargetMode_DIRECT)
    storage = Storage::Storage.new(environment)
    staging = storage.staging

    disk = Storage::Disk.create(staging, "/dev/sda")
    disk.size = 256 * Storage.GiB

    encryption = disk.create_encryption("cr_data")
    encryption.password = "s3cr3t"

    fs = encryption.create_filesystem(Storage::FsType_XFS)
    fs.add_mountpoint("/data")

    # rubocop:disable Style/StringLiterals

    result = ['---',
              '- disk:',
              '    name: "/dev/sda"',
              '    size: 256 GiB',
              '    block_size: 0.5 KiB',
              '    io_size: 0 B',
              '    min_grain: 1 MiB',
              '    align_ofs: 0 B',
              '    encryption:',
              '      type: luks',
              '      name: "/dev/mapper/cr_data"',
              '      password: s3cr3t',
              '    file_system: xfs',
              '    mount_point: "/data"']

    # rubocop:enable all

    io = StringIO.new
    Y2Storage::YamlWriter.write(staging, io)
    # print io.string
    expect(io.string).to eq result.join("\n") + "\n"

  end

end
