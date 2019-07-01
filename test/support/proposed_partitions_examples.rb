#!/usr/bin/env rspec
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

  let(:target) { nil }

  it "requires /boot to be a non-encrypted ext4 partition in the booting disk" do
    expect(boot_part.filesystem_type.is?(:ext4)).to eq true
    expect(boot_part.disk).to eq boot_disk.name
    expect(boot_part).to be_a Y2Storage::Planned::Partition
    expect(boot_part.encrypt?).to eq false
  end

  context "when aiming for the recommended size" do
    it "requires /boot to be at least 200 MiB large" do
      expect(boot_part.min_size).to eq 200.MiB
    end
  end

  context "when aiming for the minimal size" do
    let(:target) { :min }

    it "requires /boot to be at least 100 MiB large" do
      expect(boot_part.min_size).to eq 100.MiB
    end
  end
end

RSpec.shared_examples "proposed GRUB partition" do
  using Y2Storage::Refinements::SizeCasts

  let(:target) { nil }

  it "requires it to be on the boot disk" do
    expect(grub_part.disk).to eq boot_disk.name
  end

  it "requires it to have the correct id" do
    expect(grub_part.partition_id.is?(:bios_boot)).to eq true
  end

  it "requires it to be a non-encrypted partition" do
    expect(grub_part).to be_a Y2Storage::Planned::Partition
    expect(grub_part.encrypt?).to eq false
  end

  context "when aiming for the recommended size" do
    let(:target) { :desired }

    it "requires it to be at least 4 MiB (Grub2 stages 1+2, needed Grub modules and extra space)" do
      expect(grub_part.min).to eq 4.MiB
    end

    it "requires it to be at most 8 MiB (anything bigger would mean wasting space)" do
      expect(grub_part.max).to eq 8.MiB
    end
  end

  context "when aiming for the minimal size" do
    let(:target) { :min }

    it "requires it to be at least 2 MiB (Grub2 stages 1+2 and needed Grub modules)" do
      expect(grub_part.min).to eq 2.MiB
    end

    it "requires it to be at most 8 MiB (anything bigger would mean wasting space)" do
      expect(grub_part.max).to eq 8.MiB
    end
  end
end

RSpec.shared_examples "proposed EFI partition basics" do
  using Y2Storage::Refinements::SizeCasts

  let(:target) { nil }

  it "requires /boot/efi to be on the boot disk" do
    expect(efi_part.disk).to eq boot_disk.name
  end

  it "requires /boot/efi to be a non-encrypted vfat partition" do
    expect(efi_part).to be_a Y2Storage::Planned::Partition
    expect(efi_part.encrypt?).to eq false
    expect(efi_part.filesystem_type.is?(:vfat)).to eq true
  end

  it "requires /boot/efi to be close enough to the beginning of disk" do
    expect(efi_part.max_start_offset).to eq 2.TiB
  end
end

RSpec.shared_examples "flexible size EFI partition" do
  using Y2Storage::Refinements::SizeCasts

  context "when aiming for the recommended size" do
    let(:target) { :desired }

    it "requires /boot/efi to be exactly 500 MiB large (enough for several operating systems)" do
      expect(efi_part.min_size).to eq 500.MiB
      expect(efi_part.max_size).to eq 500.MiB
    end
  end

  context "when aiming for the minimal size" do
    let(:target) { :min }

    it "requires it to be at least 256 MiB (min size for FAT32 in drives with 4-KiB-per-sector)" do
      expect(efi_part.min).to eq 256.MiB
    end

    it "requires it to be at most 500 MiB (enough space for several operating systems)" do
      expect(efi_part.max).to eq 500.MiB
    end
  end
end

RSpec.shared_examples "minimalistic EFI partition" do
  using Y2Storage::Refinements::SizeCasts

  context "when aiming for the recommended size" do
    let(:target) { :desired }

    it "requires /boot/efi to be exactly 256 MiB large (always FAT32 min size)" do
      expect(efi_part.min_size).to eq 256.MiB
      expect(efi_part.max_size).to eq 256.MiB
    end
  end

  context "when aiming for the minimal size" do
    let(:target) { :min }

    it "requires /boot/efi to be exactly 256 MiB large (always FAT32 min size)" do
      expect(efi_part.min_size).to eq 256.MiB
      expect(efi_part.max_size).to eq 256.MiB
    end
  end
end

RSpec.shared_examples "proposed PReP partition" do
  using Y2Storage::Refinements::SizeCasts

  let(:target) { nil }

  it "requires it to be on the boot disk" do
    expect(prep_part.disk).to eq boot_disk.name
  end

  it "requires it to be a non-encrypted partition" do
    expect(prep_part).to be_a Y2Storage::Planned::Partition
    expect(prep_part.encrypt?).to eq false
  end

  it "requires it to be bootable (ms-dos partition table) for some firmwares to find it" do
    expect(prep_part.bootable).to eq true
  end

  # For more information, see the "Relevant Bugs during SLE15 beta phase"
  # in doc/boot-partition.md
  it "requires it to be primary since some firmwares cannot find logical partitions" do
    expect(prep_part.primary).to eq true
  end

  it "requires no particular position for it in the disk (since there is no evidence of such so far)" do
    expect(prep_part.max_start_offset).to be_nil
  end

  context "when aiming for the recommended size" do
    let(:target) { :desired }

    it "requires it to be at least 4 MiB (Grub2 stages 1+2, needed Grub modules and extra space)" do
      expect(prep_part.min).to eq 4.MiB
    end

    # https://bugzilla.suse.com/show_bug.cgi?id=1081979
    it "requires it to be at most 8 MiB (some firmwares will fail to load bigger ones)" do
      expect(prep_part.max).to eq 8.MiB
    end
  end

  context "when aiming for the minimal size" do
    let(:target) { :min }

    it "requires it to be at least 2 MiB (Grub2 stages 1+2 and needed Grub modules)" do
      expect(prep_part.min).to eq 2.MiB
    end

    # https://bugzilla.suse.com/show_bug.cgi?id=1081979
    it "requires it to be at most 8 MiB (some firmwares will fail to load bigger ones)" do
      expect(prep_part.max).to eq 8.MiB
    end
  end
end

RSpec.shared_examples "proposed /boot/zipl partition" do
  using Y2Storage::Refinements::SizeCasts

  let(:target) { nil }

  it "requires /boot/zipl to be on the boot disk" do
    expect(zipl_part.disk).to eq boot_disk.name
  end

  it "requires /boot/zipl to be a non-encrypted partition" do
    expect(zipl_part).to be_a Y2Storage::Planned::Partition
    expect(zipl_part.encrypt?).to eq false
  end

  it "requires /boot/zipl to be formated as ext2" do
    expect(zipl_part.filesystem_type.is?(:ext2)).to eq true
  end

  it "requires /boot/zipl to be at most 300 MiB (anything bigger would mean wasting space)" do
    expect(zipl_part.max_size).to eq 300.MiB
  end

  context "when aiming for the recommended size (first proposal attempt)" do
    let(:target) { :desired }

    it "requires /boot/zipl to be at least 200 MiB (Grub2, one kernel+initrd and extra space)" do
      expect(zipl_part.min_size).to eq 200.MiB
    end
  end

  context "when aiming for the minimal size" do
    let(:target) { :min }

    it "requires /boot/zipl to be at least 100 MiB (Grub2 and one kernel+initrd)" do
      expect(zipl_part.min_size).to eq 100.MiB
    end
  end
end
