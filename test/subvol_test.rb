#!/usr/bin/env rspec

require_relative "spec_helper"
require "y2storage/subvol"
Yast.import "Arch"


describe Y2Storage::Subvol do

  context "#new" do
    let(:current_arch) { Yast::Arch.arch_short }

    describe "Simple subvol with defaults" do
      subject { Y2Storage::Subvol.new("var/spool") }

      it "has the correct path" do
        expect(subject.path).to be == "var/spool"
      end

      it "is COW" do
        expect(subject.cow?).to be true
      end

      it "is not arch-specific" do
        expect(subject.arch_specific?).to be false
      end

      it "matches arch 'fake'" do
        expect(subject.matches_arch?("fake")).to be true
      end
    end

    describe "NoCOW subvol" do
      subject { Y2Storage::Subvol.new("var/lib/mysql", copy_on_write: false) }

      it "is NoCOW" do
        expect(subject.no_cow?).to be true
      end

      it "is not arch-specific" do
        expect(subject.arch_specific?).to be false
      end
    end

    describe "simple arch-specific subvol" do
      subject { Y2Storage::Subvol.new("boot/grub2/fake-arch", archs: ["fake-arch"]) }

      it "is arch specific" do
        expect(subject.arch_specific?).to be true
      end

      it "does not match the current arch" do
        expect(subject.current_arch?).to be false
      end
    end

    describe "arch-specific subvol for current arch" do
      subject { Y2Storage::Subvol.new("boot/grub2/fake-arch", archs: ["fake-arch", current_arch]) }

      it "is arch specific" do
        expect(subject.arch_specific?).to be true
      end

      it "matches the current arch" do
        expect(subject.current_arch?).to be true
      end
    end

    describe "arch-specific subvol for everything except the current arch" do
      subject { Y2Storage::Subvol.new("boot/grub2/fake-arch", archs: ["!#{current_arch}"]) }

      it "does not match the current arch" do
        expect(subject.current_arch?).to be false
      end
    end
  end

  context ".create_from_xml" do
    describe "Fully specified subvol" do
      subject do
        xml = { "path" => "var/fake", "copy_on_write" => false, "archs" => "fake, ppc,  !  foo" }
        Y2Storage::Subvol.create_from_xml( xml )
      end

      it "has the correct path" do
        expect(subject.path).to be == "var/fake"
      end

      it "is NoCOW" do
        expect(subject.no_cow?).to be true
      end

      it "is tolerant against whitespace in the archs list" do
        expect(subject.archs).to be == ["fake", "ppc", "!foo"]
      end

      it "matches arch 'fake'" do
        expect(subject.matches_arch?("fake")).to be true
      end

      it "matches arch 'ppc'" do
        expect(subject.matches_arch?("ppc")).to be true
      end

      it "does not match arch 'foo'" do
        expect(subject.matches_arch?("foo")).to be false
      end

      it "does not match arch 'bar'" do
        expect(subject.matches_arch?("bar")).to be false
      end

    end

    describe "Minimalistic subvol" do
      subject do
        xml = { "path" => "var/fake" }
        Y2Storage::Subvol.create_from_xml( xml )
      end

      it "has the correct path" do
        expect(subject.path).to be == "var/fake"
      end

      it "is COW" do
        expect(subject.cow?).to be true
      end

      it "is not arch-specific" do
        expect(subject.arch_specific?).to be false
      end

      it "matches arch 'fake'" do
        expect(subject.matches_arch?("fake")).to be true
      end
    end
  end

  context "#<=>" do
    let(:a) { Y2Storage::Subvol.new("aaa") }
    let(:b) { Y2Storage::Subvol.new("bbb") }
    let(:c) { Y2Storage::Subvol.new("ccc") }

    describe "Sorting subvol arrays" do
      subject { [b, c, a].sort }
      it "sorts by path" do
        expect(subject[0].path).to be == "aaa"
        expect(subject[1].path).to be == "bbb"
        expect(subject[2].path).to be == "ccc"
      end
    end
  end

  context ".fallback_list" do
    let(:fallbacks) { Y2Storage::Subvol.fallback_list }

    describe "var/cache subvolume" do
      subject { fallbacks.find { |subvol| subvol.path == "var/cache" } }

      it "is in the fallback list" do
        expect(subject).not_to be_nil
      end

      it "is COW" do
        expect(subject.cow?).to be true
      end

      it "is not arch-specific" do
        expect(subject.arch_specific?).to be false
      end
    end

    describe "var/lib/mariadb subvolume" do
      subject { fallbacks.find { |subvol| subvol.path == "var/lib/mariadb" } }

      it "is in the fallback list" do
        expect(subject).not_to be_nil
      end

      it "is NoCOW" do
        expect(subject.no_cow?).to be true
      end

      it "is not arch-specific" do
        expect(subject.arch_specific?).to be false
      end
    end
  end

end
