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

require "y2storage/refinements"

RSpec.shared_examples "proposed boot partition" do
  using Y2Storage::Refinements::SizeCasts

  it "requires /boot to be ext4 with at least 100 MiB" do
    expect(boot_part.filesystem_type.is?(:ext4)).to eq true
    expect(boot_part.min).to eq 100.MiB
  end

  it "requires /boot to be a non-encrypted partition in the system disk" do
    expect(boot_part.disk).to eq root_device
    expect(boot_part.plain_partition?).to eq true
  end

  it "recommends /boot to be 200 MiB" do
    expect(boot_part.desired).to eq 200.MiB
  end
end

RSpec.shared_examples "proposed GRUB partition" do
  using Y2Storage::Refinements::SizeCasts

  it "requires it to have the correct id" do
    expect(grub_part.partition_id.is?(:bios_boot)).to eq true
  end

  it "requires it to be a non-encrypted partition" do
    expect(grub_part.plain_partition?).to eq true
  end

  it "requires it to be between 256KiB and 8MiB, despite the alignment" do
    expect(grub_part.min).to eq 256.KiB
    expect(grub_part.max).to eq 8.MiB
    expect(grub_part.align).to eq :keep_size
  end

  it "recommends it to be 1 MiB" do
    expect(grub_part.desired).to eq 1.MiB
  end
end

RSpec.shared_examples "proposed EFI partition" do
  using Y2Storage::Refinements::SizeCasts

  it "requires /boot/efi to be vfat with at least 33 MiB" do
    expect(efi_part.filesystem_type.is?(:vfat)).to eq true
    expect(efi_part.min).to eq 33.MiB
  end

  it "requires /boot/efi to be a non-encrypted partition" do
    expect(efi_part.plain_partition?).to eq true
  end

  it "recommends /boot/efi to be 500 MiB" do
    expect(efi_part.desired).to eq 500.MiB
  end

  it "requires /boot/efi to be close enough to the beginning of disk" do
    expect(efi_part.max_start_offset).to eq 2.TiB
  end
end

RSpec.shared_examples "proposed PReP partition" do
  using Y2Storage::Refinements::SizeCasts

  it "requires it to be between 256KiB and 8MiB, despite the alignment" do
    expect(prep_part.min).to eq 256.KiB
    expect(prep_part.max).to eq 8.MiB
    expect(prep_part.align).to eq :keep_size
  end

  it "recommends it to be 1 MiB" do
    expect(prep_part.desired).to eq 1.MiB
  end

  it "requires it to be a non-encrypted partition" do
    expect(prep_part.plain_partition?).to eq true
  end

  it "requires it to be bootable (ms-dos partition table)" do
    expect(prep_part.bootable).to eq true
  end
end

RSpec.shared_examples "proposed /boot/zipl partition" do
  using Y2Storage::Refinements::SizeCasts

  it "requires /boot/zipl to be ext2 with at least 100 MiB" do
    expect(zipl_part.filesystem_type.is?(:ext2)).to eq true
    expect(zipl_part.min).to eq 100.MiB
  end

  it "requires /boot/zipl to be a non-encrypted partition in the system disk" do
    expect(zipl_part.disk).to eq root_device
    expect(zipl_part.plain_partition?).to eq true
  end

  it "recommends /boot/zipl to be 200 MiB" do
    expect(zipl_part.desired).to eq 200.MiB
  end
end
