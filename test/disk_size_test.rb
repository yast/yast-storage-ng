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
require "y2storage/disk_size"

describe Y2Storage::DiskSize do
  using Y2Storage::Refinements::SizeCasts
  let(:zero) { Y2Storage::DiskSize.zero }
  let(:unlimited) { Y2Storage::DiskSize.unlimited }
  let(:one_byte) { Y2Storage::DiskSize.new(1) }

  describe "constructed empty" do
    it "should have a to_i of 0" do
      disk_size = Y2Storage::DiskSize.new
      expect(disk_size.to_i).to be == 0
    end
  end

  describe "created with 42 KiB" do
    disk_size = Y2Storage::DiskSize.KiB(42)
    it "should return the correct human readable string" do
      expect(disk_size.to_s).to be == "42.00 KiB"
    end
    it "should have the correct numeric value internally" do
      expect(disk_size.to_i).to be == 42 * 1024
    end
  end

  describe "created with 43 MiB" do
    disk_size = Y2Storage::DiskSize.MiB(43)
    it "should return the correct human readable string" do
      expect(disk_size.to_s).to be == "43.00 MiB"
    end
    it "should have the correct numeric value internally" do
      expect(disk_size.to_i).to be == 43 * 1024**2
    end
  end

  describe "created with 44 GiB" do
    disk_size = Y2Storage::DiskSize.GiB(44)
    it "should return the correct human readable string" do
      expect(disk_size.to_s).to be == "44.00 GiB"
    end
    it "should have the correct numeric value internally" do
      expect(disk_size.to_i).to be == 44 * 1024**3
    end
  end

  describe "created with 45 TiB" do
    disk_size = Y2Storage::DiskSize.TiB(45)
    it "should return the correct human readable string" do
      expect(disk_size.to_s).to be == "45.00 TiB"
    end
    it "should have the correct numeric value internally" do
      expect(disk_size.to_i).to be == 45 * 1024**4
    end
  end

  describe "created with 46 PiB" do
    disk_size = Y2Storage::DiskSize.PiB(46)
    it "should return the correct human readable string" do
      expect(disk_size.to_s).to be == "46.00 PiB"
    end
    it "should have the correct numeric value internally" do
      expect(disk_size.to_i).to be == 46 * 1024**5
    end
  end

  describe "created with 47 EiB" do
    disk_size = Y2Storage::DiskSize.EiB(47)
    it "should return the correct human readable string" do
      expect(disk_size.to_s).to be == "47.00 EiB"
    end
    it "should not overflow and have the correct numeric value internally" do
      expect(disk_size.to_i).to be == 47 * 1024**6
    end
  end

  describe "created with a huge number" do
    disk_size = Y2Storage::DiskSize.TiB(48 * 1024**5)
    it "should return the correct human readable string" do
      expect(disk_size.to_s).to be == "49152.00 YiB"
    end
    it "should not overflow" do
      expect(disk_size.to_i).to be > 0
    end
    it "should have the correct numeric value internally" do
      expect(disk_size.to_i).to be == 48 * 1024**9
    end
  end

  describe "created with 1024 GiB" do
    disk_size = Y2Storage::DiskSize.GiB(1024)
    it "should use the next higher unit (TiB) from 1024 on" do
      expect(disk_size.to_s).to be == "1.00 TiB"
    end
  end

  describe "arithmetic operations" do
    it "should accept addition of another DiskSize" do
      disk_size = Y2Storage::DiskSize.GiB(10) + Y2Storage::DiskSize.GiB(20)
      expect(disk_size.to_i).to be == 30 * 1024**3
    end
    it "should accept addition of an int" do
      disk_size = Y2Storage::DiskSize.MiB(20) + 512
      expect(disk_size.to_i).to be == 20 * 1024**2 + 512
    end
    it "should accept multiplication with an int" do
      disk_size = Y2Storage::DiskSize.MiB(12) * 3
      expect(disk_size.to_i).to be == 12 * 1024**2 * 3
    end
    it "should accept division by an int" do
      disk_size = Y2Storage::DiskSize.MiB(12) / 3
      expect(disk_size.to_i).to be == 12 / 3 * 1024**2
    end
    it "should refuse multiplication with another DiskSize" do
      expect { Y2Storage::DiskSize.MiB(12) * Y2Storage::DiskSize.MiB(3) }
        .to raise_exception TypeError
    end
  end

  describe "arithmetic operations with unlimited and DiskSize" do
    unlimited = Y2Storage::DiskSize.unlimited
    disk_size = Y2Storage::DiskSize.GiB(42)
    it "should return unlimited" do
      expect(unlimited + disk_size).to be == unlimited
      expect(disk_size + unlimited).to be == unlimited
      expect(unlimited - disk_size).to be == unlimited
      expect(disk_size - unlimited).to be == unlimited
      # DiskSize * DiskSize and DiskSize / DiskSize are undefined
    end
  end

  describe "arithmetic operations with unlimited and a number" do
    unlimited = Y2Storage::DiskSize.unlimited
    number    = 7
    it "should return unlimited" do
      expect(unlimited + number).to be == unlimited
      expect(unlimited - number).to be == unlimited
      expect(unlimited * number).to be == unlimited
      expect(unlimited / number).to be == unlimited
    end
  end

  describe "comparison" do
    disk_size1 = Y2Storage::DiskSize.GiB(24)
    disk_size2 = Y2Storage::DiskSize.GiB(32)
    disk_size3 = Y2Storage::DiskSize.GiB(32)
    it "operator < should compare correctly" do
      expect(disk_size1 < disk_size2).to be == true
      expect(disk_size2 < disk_size3).to be == false
    end
    it "operator > should compare correctly" do
      expect(disk_size1 > disk_size2).to be == false
      expect(disk_size2 > disk_size3).to be == false
    end
    it "operator == should compare correctly" do
      expect(disk_size2 == disk_size3).to be == true
    end
    it "operator != should compare correctly" do
      expect(disk_size1 != disk_size2).to be == true
    end
    it "operator <= should compare correctly" do
      expect(disk_size2 <= disk_size3).to be == true
    end
    it "operator >= should compare correctly" do
      expect(disk_size2 >= disk_size3).to be == true
    end
  end

  describe "comparison with unlimited" do
    unlimited = Y2Storage::DiskSize.unlimited
    disk_size = Y2Storage::DiskSize.GiB(42)
    it "should compare any disk size correctly with unlimited" do
      expect(disk_size).to be < unlimited
      expect(disk_size).to_not be > unlimited
      expect(disk_size).to_not eq unlimited
    end
    it "should compare unlimited correctly with any disk size" do
      expect(unlimited).to be > disk_size
      expect(unlimited).to_not be < disk_size
      expect(unlimited).to_not eq disk_size
    end
    it "should compare unlimited correctly with unlimited" do
      expect(unlimited).to_not be > unlimited
      expect(unlimited).to_not be < unlimited
      expect(unlimited).to eq unlimited
    end
  end

  describe "unit exponent" do
    it "should be correct for KiB" do
      expect(Y2Storage::DiskSize.unit_exponent("KiB")).to be == 1
    end
    it "should be correct for MiB" do
      expect(Y2Storage::DiskSize.unit_exponent("MiB")).to be == 2
    end
    it "should be correct for GiB" do
      expect(Y2Storage::DiskSize.unit_exponent("GiB")).to be == 3
    end
    it "should be correct for TiB" do
      expect(Y2Storage::DiskSize.unit_exponent("TiB")).to be == 4
    end
    it "should be correct for PiB" do
      expect(Y2Storage::DiskSize.unit_exponent("PiB")).to be == 5
    end
    it "should be correct for EiB" do
      expect(Y2Storage::DiskSize.unit_exponent("EiB")).to be == 6
    end
    it "should be correct for ZiB" do
      expect(Y2Storage::DiskSize.unit_exponent("ZiB")).to be == 7
    end
    it "should be correct for YiB" do
      expect(Y2Storage::DiskSize.unit_exponent("YiB")).to be == 8
    end
    it "should raise an exception for invalid units" do
      expect { Y2Storage::DiskSize.unit_exponent("WTF") }.to raise_error(ArgumentError)
      expect { Y2Storage::DiskSize.unit_exponent("MB") }.to raise_error(ArgumentError)
      expect { Y2Storage::DiskSize.unit_exponent("GB") }.to raise_error(ArgumentError)
      expect { Y2Storage::DiskSize.unit_exponent("TB") }.to raise_error(ArgumentError)
    end
  end

  describe "parsing from string" do
    it "should work with just an integer" do
      expect(described_class.parse("0").to_i).to be == 0
      expect(described_class.parse("7").to_i).to be == 7
    end
    it "should work with integer and unit" do
      expect(described_class.parse("42 GiB").to_i).to be == 42 * 1024**3
    end
    it "should work with float and unit" do
      expect(described_class.parse("43.00 GiB").to_i).to be == 43 * 1024**3
    end
    it "should work with just an integer" do
      expect(described_class.parse("0").to_i).to be == 0
    end
    it "should tolerate more embedded whitespace" do
      expect(described_class.parse("44   MiB").to_i).to be == 44 * 1024**2
    end
    it "should tolerate more surrounding whitespace" do
      expect(described_class.parse("   45   TiB  ").to_i).to be == 45 * 1024**4
      expect(described_class.parse("  46   ").to_i).to be == 46
    end
    it "should accept \"unlimited\"" do
      expect(described_class.parse("unlimited").to_i).to be == -1
    end
    it "should accept \"unlimited\" with surrounding whitespace" do
      expect(described_class.parse("  unlimited ").to_i).to be == -1
    end
    it "should accept its own output" do
      expect(described_class.parse(described_class.GiB(42).to_s).to_i).to be == 42 * 1024**3
      expect(described_class.parse(described_class.new(43).to_s).to_i).to be == 43
      expect(described_class.parse(described_class.zero.to_s).to_i).to be == 0
      expect(described_class.parse(described_class.unlimited.to_s).to_i).to be == -1
    end
    it "should reject invalid input" do
      expect { described_class.parse("wrglbrmpf") }.to raise_error(ArgumentError)
      expect { described_class.parse("47 00 GiB") }.to raise_error(ArgumentError)
      expect { described_class.parse("0FFF MiB") }.to raise_error(ArgumentError)
    end
  end

  describe "#ceil" do
    it "returns the same value if any of the operands is zero" do
      expect(zero.ceil(4.MiB)).to eq zero
      expect(4.MiB.ceil(zero)).to eq 4.MiB
      expect(zero.ceil(zero)).to eq zero
    end

    it "returns the same value if any of the operands is unlimited" do
      expect(unlimited.ceil(8.GiB)).to eq unlimited
      expect(8.GiB.ceil(unlimited)).to eq 8.GiB
      expect(unlimited.ceil(zero)).to eq unlimited
      expect(unlimited.ceil(unlimited)).to eq unlimited
    end

    it "returns the same value when rounding to 1 byte" do
      expect(4.KiB.ceil(one_byte)).to eq 4.KiB
    end

    it "returns the same value when it's divisible by the size" do
      expect(12.MiB.ceil(4.MiB)).to eq 12.MiB
    end

    it "rounds up to the next divisible size otherwise" do
      expect(9.MiB.ceil(4.MiB)).to eq 12.MiB
      expect(10.MiB.ceil(4.MiB)).to eq 12.MiB
      expect(11.MiB.ceil(4.MiB)).to eq 12.MiB
      almost_exact = 12.MiB - one_byte
      expect(almost_exact.ceil(4.MiB)).to_not eq almost_exact
      expect(almost_exact.ceil(4.MiB)).to eq 12.MiB
    end
  end

  describe "#floor" do
    it "returns the same value if any of the operands is zero" do
      expect(zero.floor(4.MiB)).to eq zero
      expect(4.MiB.floor(zero)).to eq 4.MiB
      expect(zero.floor(zero)).to eq zero
    end

    it "returns the same value if any of the operands is unlimited" do
      expect(unlimited.floor(8.GiB)).to eq unlimited
      expect(8.GiB.floor(unlimited)).to eq 8.GiB
      expect(unlimited.floor(zero)).to eq unlimited
      expect(unlimited.floor(unlimited)).to eq unlimited
    end

    it "returns the same value when rounding to 1 byte" do
      expect(4.KiB.floor(one_byte)).to eq 4.KiB
    end

    it "returns the same value when it's divisible by the size" do
      expect(12.MiB.floor(4.MiB)).to eq 12.MiB
    end

    it "rounds down to the previous divisible size otherwise" do
      expect(9.MiB.floor(4.MiB)).to eq 8.MiB
      expect(10.MiB.floor(4.MiB)).to eq 8.MiB
      expect(11.MiB.floor(4.MiB)).to eq 8.MiB
      almost_exact = 8.MiB + one_byte
      expect(almost_exact.floor(4.MiB)).to_not eq almost_exact
      expect(almost_exact.floor(4.MiB)).to eq 8.MiB
    end
  end
end
