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

require_relative "spec_helper"
require "y2storage/planned_subvol"
require "pp"
Yast.import "Arch"

describe Y2Storage::PlannedSubvol do

  context "#new" do
    let(:current_arch) { Yast::Arch.arch_short }

    describe "Simple subvol with defaults" do
      subject { Y2Storage::PlannedSubvol.new("var/spool") }

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
      subject { Y2Storage::PlannedSubvol.new("var/lib/mysql", copy_on_write: false) }

      it "is NoCOW" do
        expect(subject.no_cow?).to be true
      end

      it "is not arch-specific" do
        expect(subject.arch_specific?).to be false
      end
    end

    describe "simple arch-specific subvol" do
      subject { Y2Storage::PlannedSubvol.new("boot/grub2/fake-arch", archs: ["fake-arch"]) }

      it "is arch specific" do
        expect(subject.arch_specific?).to be true
      end

      it "does not match the current arch" do
        expect(subject.current_arch?).to be false
      end
    end

    describe "arch-specific subvol for current arch" do
      # rubocop: disable Metrics/LineLength
      subject { Y2Storage::PlannedSubvol.new("boot/grub2/fake-arch", archs: ["fake-arch", current_arch]) }
      # rubocop: enable Metrics/LineLength

      it "is arch specific" do
        expect(subject.arch_specific?).to be true
      end

      it "matches the current arch" do
        expect(subject.current_arch?).to be true
      end
    end

    describe "arch-specific subvol for everything except the current arch" do
      subject { Y2Storage::PlannedSubvol.new("boot/grub2/fake-arch", archs: ["!#{current_arch}"]) }

      it "does not match the current arch" do
        expect(subject.current_arch?).to be false
      end
    end
  end

  context ".create_from_xml" do
    describe "Fully specified subvol" do
      subject do
        xml = { "path" => "var/fake", "copy_on_write" => false, "archs" => "fake, ppc,  !  foo" }
        Y2Storage::PlannedSubvol.create_from_xml(xml)
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
        Y2Storage::PlannedSubvol.create_from_xml(xml)
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
    let(:a) { Y2Storage::PlannedSubvol.new("aaa") }
    let(:b) { Y2Storage::PlannedSubvol.new("bbb") }
    let(:c) { Y2Storage::PlannedSubvol.new("ccc") }

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
    let(:fallbacks) { Y2Storage::PlannedSubvol.fallback_list }

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
