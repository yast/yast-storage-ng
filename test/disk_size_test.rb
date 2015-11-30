#!/usr/bin/env rspec

require_relative "spec_helper"
require "storage/disk_size"

using Yast::Storage

describe Yast::Storage::DiskSize do

  describe "constructed empty" do
    it "should have a size_k of 0" do
      disk_size = Yast::Storage::DiskSize.new
      expect( disk_size.size_k ).to be == 0
    end
  end

  describe "created with 42 kiB" do
    disk_size = Yast::Storage::DiskSize.kiB(42)
    it "should return the correct human readable string" do
      expect( disk_size.to_s ).to be == "42.00 kiB"
    end
    it "should have the correct numeric value internally" do
      expect( disk_size.size_k ).to be == 42
    end
  end

  describe "created with 43 MiB" do
    disk_size = Yast::Storage::DiskSize.MiB(43)
    it "should return the correct human readable string" do
      expect( disk_size.to_s ).to be == "43.00 MiB"
    end
    it "should have the correct numeric value internally" do
      expect( disk_size.size_k ).to be == 43 * 1024
    end
  end

  describe "created with 44 GiB" do
    disk_size = Yast::Storage::DiskSize.GiB(44)
    it "should return the correct human readable string" do
      expect( disk_size.to_s ).to be == "44.00 GiB"
    end
    it "should have the correct numeric value internally" do
      expect( disk_size.size_k ).to be == 44 * 1024**2
    end
  end

  describe "created with 45 TiB" do
    disk_size = Yast::Storage::DiskSize.TiB(45)
    it "should return the correct human readable string" do
      expect( disk_size.to_s ).to be == "45.00 TiB"
    end
    it "should have the correct numeric value internally" do
      expect( disk_size.size_k ).to be == 45 * 1024**3
    end
  end

  describe "created with 46 PiB" do
    disk_size = Yast::Storage::DiskSize.PiB(46)
    it "should return the correct human readable string" do
      expect( disk_size.to_s ).to be == "46.00 PiB"
    end
    it "should have the correct numeric value internally" do
      expect( disk_size.size_k ).to be == 46 * 1024**4
    end
  end

  describe "created with 47 EiB" do
    disk_size = Yast::Storage::DiskSize.EiB(47)
    it "should return the correct human readable string" do
      expect( disk_size.to_s ).to be == "47.00 EiB"
    end
    it "should not overflow and have the correct numeric value internally" do
      expect( disk_size.size_k ).to be == 47 * 1024**5
    end
  end

  describe "created with a huge number" do
    disk_size = Yast::Storage::DiskSize.TiB(48 * 1024**5)
    it "should return the correct human readable string" do
      expect( disk_size.to_s ).to be == "49152.00 YiB"
    end
    it "should not overflow" do
      expect( disk_size.size_k ).to be > 0
    end
    it "should have the correct numeric value internally" do
      expect( disk_size.size_k ).to be == 48 * 1024**8
    end
  end

  describe "arithmetic operations" do
    it "should accept addition of another DiskSize" do
      disk_size = Yast::Storage::DiskSize.GiB(10) + Yast::Storage::DiskSize.GiB(20)
      expect( disk_size.size_k ).to be == 30 * 1024**2
    end
    it "should accept addition of an int" do
      disk_size = Yast::Storage::DiskSize.MiB(20) + 512
      expect( disk_size.size_k ).to be == 20 * 1024 + 512
    end
    it "should accept multiplication with an int" do
      disk_size = Yast::Storage::DiskSize.MiB(12) * 3
      expect( disk_size.size_k ).to be == 12 * 1024 * 3
    end
    it "should accept division by an int" do
      disk_size = Yast::Storage::DiskSize.MiB(12) / 3
      expect( disk_size.size_k ).to be == 12 / 3 * 1024
    end
    it "should refuse multiplication with another DiskSize" do
      expect{ Yast::Storage::DiskSize.MiB(12) * Yast::Storage::DiskSize.MiB(3) }.to raise_exception TypeError
    end
  end

  describe "comparison" do
    disk_size1 = Yast::Storage::DiskSize.GiB(24)
    disk_size2 = Yast::Storage::DiskSize.GiB(32)
    disk_size3 = Yast::Storage::DiskSize.GiB(32)
    it "operator < should compare correctly" do
      expect( disk_size1 < disk_size2 ).to be == true
      expect( disk_size2 < disk_size3 ).to be == false
    end
    it "operator > should compare correctly" do
      expect( disk_size1 > disk_size2 ).to be == false
      expect( disk_size2 > disk_size3 ).to be == false
    end
    it "operator == should compare correctly" do
      expect( disk_size2 == disk_size3 ).to be == true
    end
    it "operator != should compare correctly" do
      expect( disk_size1 != disk_size2 ).to be == true
    end
    it "operator <= should compare correctly" do
      expect( disk_size2 <= disk_size3 ).to be == true
    end
    it "operator >= should compare correctly" do
      expect( disk_size2 >= disk_size3 ).to be == true
    end
  end

  describe "comparison with unlimited" do
    unlimited = Yast::Storage::DiskSize.unlimited
    disk_size = Yast::Storage::DiskSize.GiB(42)
    it "should compare any disk size correctly with unlimited" do
      expect( disk_size <  unlimited ).to be == true
      expect( disk_size >  unlimited ).to be == false
      expect( disk_size == unlimited ).to be == false
    end
    it "should compare unlimited correctly with any disk size" do
      expect( unlimited >  disk_size ).to be == true
      expect( unlimited <  disk_size ).to be == false
      expect( unlimited == disk_size ).to be == false
    end
    it "should compare unlimited correctly with unlimited" do
      expect( unlimited >  unlimited ).to be == false
      expect( unlimited <  unlimited ).to be == false
      expect( unlimited == unlimited ).to be == true
    end
  end

  describe "unit exponent" do
    it "should be correct for kiB" do
      expect( Yast::Storage::DiskSize.unit_exponent("kiB") ).to be == 0
    end
    it "should be correct for MiB" do
      expect( Yast::Storage::DiskSize.unit_exponent("MiB") ).to be == 1
    end
    it "should be correct for GiB" do
      expect( Yast::Storage::DiskSize.unit_exponent("GiB") ).to be == 2
    end
    it "should be correct for TiB" do
      expect( Yast::Storage::DiskSize.unit_exponent("TiB") ).to be == 3
    end
    it "should be correct for PiB" do
      expect( Yast::Storage::DiskSize.unit_exponent("PiB") ).to be == 4
    end
    it "should be correct for EiB" do
      expect( Yast::Storage::DiskSize.unit_exponent("EiB") ).to be == 5
    end
    it "should be correct for ZiB" do
      expect( Yast::Storage::DiskSize.unit_exponent("ZiB") ).to be == 6
    end
    it "should be correct for YiB" do
      expect( Yast::Storage::DiskSize.unit_exponent("YiB") ).to be == 7
    end
    it "should raise an exception for invalid units" do
      expect { Yast::Storage::DiskSize.unit_exponent("WTF") }.to raise_error(ArgumentError)
      expect { Yast::Storage::DiskSize.unit_exponent("MB" ) }.to raise_error(ArgumentError)
      expect { Yast::Storage::DiskSize.unit_exponent("GB" ) }.to raise_error(ArgumentError)
      expect { Yast::Storage::DiskSize.unit_exponent("TB" ) }.to raise_error(ArgumentError)
    end
  end

  describe "parsing from string" do
    it "should work with just an integer" do
      expect( Yast::Storage::DiskSize.parse("0").size_k ).to be == 0
      expect( Yast::Storage::DiskSize.parse("7").size_k ).to be == 7
    end
    it "should work with integer and unit" do
      expect( Yast::Storage::DiskSize.parse("42 GiB").size_k ).to be == 42 * 1024**2
    end
    it "should work with float and unit" do
      expect( Yast::Storage::DiskSize.parse("43.00 GiB").size_k ).to be == 43 * 1024**2
    end
    it "should work with just an integer" do
      expect( Yast::Storage::DiskSize.parse("0").size_k    ).to be == 0
    end
    it "should tolerate more embedded whitespace" do
      expect( Yast::Storage::DiskSize.parse("44   MiB"     ).size_k ).to be == 44 * 1024
    end
    it "should tolerate more surrounding whitespace" do
      expect( Yast::Storage::DiskSize.parse("   45   TiB  ").size_k ).to be == 45 * 1024**3
      expect( Yast::Storage::DiskSize.parse("  46   "      ).size_k ).to be == 46
    end
    it "should accept \"unlimited\"" do
      expect( Yast::Storage::DiskSize.parse("unlimited").size_k ).to be == -1
    end
    it "should accept \"unlimited\" with surrounding whitespace" do
      expect( Yast::Storage::DiskSize.parse("  unlimited ").size_k ).to be == -1
    end
    it "should accept its own output" do
      expect( Yast::Storage::DiskSize.parse( Yast::Storage::DiskSize.GiB(42).to_s   ).size_k ).to be == 42 * 1024**2
      expect( Yast::Storage::DiskSize.parse( Yast::Storage::DiskSize.new(43).to_s   ).size_k ).to be == 43
      expect( Yast::Storage::DiskSize.parse( Yast::Storage::DiskSize.zero.to_s      ).size_k ).to be ==  0
      expect( Yast::Storage::DiskSize.parse( Yast::Storage::DiskSize.unlimited.to_s ).size_k ).to be == -1
    end
    it "should reject invalid input" do
      expect { Yast::Storage::DiskSize.parse("wrglbrmpf") }.to raise_error(ArgumentError)
      expect { Yast::Storage::DiskSize.parse("47 00 GiB") }.to raise_error(ArgumentError)
      expect { Yast::Storage::DiskSize.parse("0FFF MiB" ) }.to raise_error(ArgumentError)
    end
  end

end
