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

  it "requires it to have the correct id" do
    expect(grub_part.partition_id.is?(:bios_boot)).to eq true
  end

  it "requires it to be a non-encrypted partition" do
    expect(grub_part).to be_a Y2Storage::Planned::Partition
    expect(grub_part.encrypt?).to eq false
  end

  context "when aiming for the recommended size" do
    let(:target) { :desired }

    it "requires it to be between 1 and 8MiB, despite the alignment" do
      expect(grub_part.min).to eq 1.MiB
      expect(grub_part.max).to eq 8.MiB
      expect(grub_part.align).to eq :keep_size
    end
  end

  context "when aiming for the minimal size" do
    let(:target) { :min }

    it "requires it to be between 256KiB and 8MiB, despite the alignment" do
      expect(grub_part.min).to eq 256.KiB
      expect(grub_part.max).to eq 8.MiB
      expect(grub_part.align).to eq :keep_size
    end
  end
end

RSpec.shared_examples "proposed EFI partition" do
  using Y2Storage::Refinements::SizeCasts

  let(:target) { nil }

  it "requires /boot/efi to be a non-encrypted vfat partition" do
    expect(efi_part).to be_a Y2Storage::Planned::Partition
    expect(efi_part.encrypt?).to eq false
    expect(efi_part.filesystem_type.is?(:vfat)).to eq true
  end

  it "requires /boot/efi to be close enough to the beginning of disk" do
    expect(efi_part.max_start_offset).to eq 2.TiB
  end

  context "when aiming for the recommended size" do
    let(:target) { :desired }

    it "requires /boot/efi to be at least 500 MiB large" do
      expect(efi_part.min_size).to eq 500.MiB
    end
  end

  context "when aiming for the minimal size" do
    let(:target) { :min }

    it "requires /boot/efi to be at least 33 MiB large" do
      expect(efi_part.min_size).to eq 33.MiB
    end
  end
end

RSpec.shared_examples "proposed PReP partition" do
  using Y2Storage::Refinements::SizeCasts

  let(:target) { nil }

  it "requires it to be a non-encrypted partition" do
    expect(prep_part).to be_a Y2Storage::Planned::Partition
    expect(prep_part.encrypt?).to eq false
  end

  it "requires it to be bootable (ms-dos partition table)" do
    expect(prep_part.bootable).to eq true
  end

  context "when aiming for the recommended size" do
    let(:target) { :desired }

    it "requires it to be between 1MiB and 8MiB, despite the alignment" do
      expect(prep_part.min).to eq 1.MiB
      expect(prep_part.max).to eq 8.MiB
      expect(prep_part.align).to eq :keep_size
    end
  end

  context "when aiming for the minimal size" do
    let(:target) { :min }

    it "requires it to be between 256KiB and 8MiB, despite the alignment" do
      expect(prep_part.min).to eq 256.KiB
      expect(prep_part.max).to eq 8.MiB
      expect(prep_part.align).to eq :keep_size
    end
  end
end

RSpec.shared_examples "proposed /boot/zipl partition" do
  using Y2Storage::Refinements::SizeCasts

  let(:target) { nil }

  it "requires /boot/zipl to be ext2 with at least 100 MiB" do
    expect(zipl_part.filesystem_type.is?(:ext2)).to eq true
  end

  it "requires /boot/zipl to be a non-encrypted partition in the boot disk" do
    expect(zipl_part.disk).to eq boot_disk.name
    expect(zipl_part).to be_a Y2Storage::Planned::Partition
    expect(zipl_part.encrypt?).to eq false
  end

  context "when aiming for the recommended size" do
    let(:target) { :desired }

    it "requires /boot/zipl to be at least 200 MiB large" do
      expect(zipl_part.min_size).to eq 200.MiB
    end
  end

  context "when aiming for the minimal size" do
    let(:target) { :min }

    it "requires /boot/zipl to be at least 100 MiB large" do
      expect(zipl_part.min_size).to eq 100.MiB
    end
  end
end
