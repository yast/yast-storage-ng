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

describe Y2Storage::YamlWriter do

  before do
    Y2Storage::StorageManager.create_test_instance
  end
  let(:staging) { Y2Storage::StorageManager.instance.staging }

  it "produces yaml of a simple DASD disk setup" do

    sda = Y2Storage::Dasd.create(staging, "/dev/sda")
    sda.size = 256 * Storage.GiB
    sda.type = Y2Storage::DasdType::ECKD
    sda.format = Y2Storage::DasdFormat::LDL

    sda.create_partition_table(Y2Storage::PartitionTables::Type::DASD)

    # rubocop:disable Style/StringLiterals

    result = ['---',
              '- dasd:',
              '    name: "/dev/sda"',
              '    size: 256 GiB',
              '    block_size: 0.5 KiB',
              '    io_size: 0 B',
              '    min_grain: 1 MiB',
              '    align_ofs: 0 B',
              '    type: eckd',
              '    format: ldl',
              '    partition_table: dasd',
              '    partitions:',
              '    - free:',
              '        size: 256 GiB',
              '        start: 0 B']

    # rubocop:enable all

    io = StringIO.new
    Y2Storage::YamlWriter.write(staging, io)
    expect(io.string).to eq result.join("\n") + "\n"
  end

  it "produces yaml of a simple disk and partition setup" do

    sda = Y2Storage::Disk.create(staging, "/dev/sda")
    sda.size = 256 * Storage.GiB

    gpt = sda.create_partition_table(Y2Storage::PartitionTables::Type::GPT)

    sda1 = gpt.create_partition("/dev/sda1", Y2Storage::Region.create(2048, 1048576, 512),
      Y2Storage::PartitionType::PRIMARY)
    sda1.id = Y2Storage::PartitionId::SWAP

    swap = sda1.create_filesystem(Y2Storage::Filesystems::Type::SWAP)
    swap.mount_point = "swap"

    sda2 = gpt.create_partition("/dev/sda2", Y2Storage::Region.create(1050624, 33554432, 512),
      Y2Storage::PartitionType::PRIMARY)

    ext4 = sda2.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
    ext4.mount_point = "/"
    ext4.fstab_options = ["acl", "user_xattr"]

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

    sda = Y2Storage::Disk.create(staging, "/dev/sda")
    sda.size = 1 * Storage.TiB

    lvm_vg = Y2Storage::LvmVg.create(staging, "system")
    lvm_vg.add_lvm_pv(sda)

    lvm_lv = lvm_vg.create_lvm_lv("root", 16 * Storage.GiB)
    lvm_lv.create_filesystem(Y2Storage::Filesystems::Type::EXT4)

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

    sda = Y2Storage::Disk.create(staging, "/dev/sda")
    sda.size = 256 * Storage.GiB

    gpt = sda.create_partition_table(Y2Storage::PartitionTables::Type::GPT)

    sda1 = gpt.create_partition("/dev/sda1", Y2Storage::Region.create(2048, 1048576, 512),
      Y2Storage::PartitionType::PRIMARY)
    sda1.id = Y2Storage::PartitionId::SWAP

    swap = sda1.create_filesystem(Y2Storage::Filesystems::Type::SWAP)
    swap.mount_point = "swap"

    sda2 = gpt.create_partition("/dev/sda2", Y2Storage::Region.create(1050624, 33554432, 512),
      Y2Storage::PartitionType::PRIMARY)

    encryption = sda2.create_encryption("cr_system")
    encryption.password = "vry!s3cret"

    ext4 = encryption.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
    ext4.mount_point = "/"
    ext4.fstab_options = ["acl", "user_xattr"]

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
              '        encryption:',
              '          type: luks',
              '          name: "/dev/mapper/cr_system"',
              '          password: vry!s3cret',
              '    - free:',
              '        size: 245247 MiB (239.50 GiB)',
              '        start: 16897 MiB (16.50 GiB)']

    # rubocop:enable all

    io = StringIO.new
    Y2Storage::YamlWriter.write(staging, io)
    expect(io.string).to eq result.join("\n") + "\n"

  end

  it "produces yaml of an lvm setup with encryption on the PV level" do

    sda = Y2Storage::Disk.create(staging, "/dev/sda")
    sda.size = 256 * Storage.GiB

    ptable = sda.create_partition_table(Y2Storage::PartitionTables::Type::MSDOS)
    blocks = sda.size.to_i / 512 - 2048

    sda1 = ptable.create_partition("/dev/sda1", Y2Storage::Region.create(2048, blocks, 512),
      Y2Storage::PartitionType::PRIMARY)
    sda1.id = Y2Storage::PartitionId::LVM

    encryption = sda1.create_encryption("cr_sda1")
    encryption.password = "s3cr3t"

    lvm_vg = Y2Storage::LvmVg.create(staging, "system")
    lvm_vg.add_lvm_pv(encryption)

    lvm_lv = lvm_vg.create_lvm_lv("root", 16 * Storage.GiB)
    fs = lvm_lv.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
    fs.mount_point = "/"

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

    sda = Y2Storage::Disk.create(staging, "/dev/sda")
    sda.size = 256 * Storage.GiB

    ptable = sda.create_partition_table(Y2Storage::PartitionTables::Type::MSDOS)
    blocks = sda.size.to_i / 512 - 2048

    sda1 = ptable.create_partition("/dev/sda1", Y2Storage::Region.create(2048, blocks, 512),
      Y2Storage::PartitionType::PRIMARY)
    sda1.id = Y2Storage::PartitionId::LVM

    lvm_vg = Y2Storage::LvmVg.create(staging, "system")
    lvm_vg.add_lvm_pv(sda1)

    lvm_lv = lvm_vg.create_lvm_lv("root", 16 * Storage.GiB)

    encryption = lvm_lv.create_encryption("cr_sda1")
    encryption.password = "s3cr3t"

    fs = encryption.create_filesystem(Y2Storage::Filesystems::Type::XFS)
    fs.mount_point = "/"

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
              '        file_system: xfs',
              '        mount_point: "/"',
              '        encryption:',
              '          type: luks',
              '          name: "/dev/mapper/cr_sda1"',
              '          password: s3cr3t',
              '    lvm_pvs:',
              '    - lvm_pv:',
              '        blk_device: "/dev/sda1"']

    # rubocop:enable all

    io = StringIO.new
    Y2Storage::YamlWriter.write(staging, io)
    expect(io.string).to eq result.join("\n") + "\n"

  end

  it "produces yaml of a filesystem directly on a disk without a partition table" do

    disk = Y2Storage::Disk.create(staging, "/dev/sda")
    disk.size = 256 * Storage.GiB

    fs = disk.create_filesystem(Y2Storage::Filesystems::Type::XFS)
    fs.mount_point = "/data"

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

    disk = Y2Storage::Disk.create(staging, "/dev/sda")
    disk.size = 256 * Storage.GiB

    encryption = disk.create_encryption("cr_data")
    encryption.password = "s3cr3t"

    fs = encryption.create_filesystem(Y2Storage::Filesystems::Type::XFS)
    fs.mount_point = "/data"

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
              '    mount_point: "/data"',
              '    encryption:',
              '      type: luks',
              '      name: "/dev/mapper/cr_data"',
              '      password: s3cr3t']

    # rubocop:enable all

    io = StringIO.new
    Y2Storage::YamlWriter.write(staging, io)
    # print io.string
    expect(io.string).to eq result.join("\n") + "\n"

  end

end
