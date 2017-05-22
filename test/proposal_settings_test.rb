#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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
require "y2storage"
Yast.import "ProductFeatures"

describe Y2Storage::ProposalSettings do
  using Y2Storage::Refinements::SizeCasts

  def stub_features(all_features)
    Yast::ProductFeatures.Import(all_features)
  end

  def stub_partitioning_features(features)
    stub_features("partitioning" => features)
  end

  describe "#read_product_features!" do
    subject(:settings) { described_class.new }

    def read_feature(feature, value)
      stub_partitioning_features(feature => value)
      settings.read_product_features!
    end

    it "sets 'use_lvm' based on the feature 'proposal_lvm'" do
      read_feature("proposal_lvm", true)
      expect(settings.use_lvm).to eq true
      read_feature("proposal_lvm", false)
      expect(settings.use_lvm).to eq false
    end

    it "sets 'use_separate_home' based on the feature 'try_separate_home'" do
      read_feature("try_separate_home", true)
      expect(settings.use_separate_home).to eq true
      read_feature("try_separate_home", false)
      expect(settings.use_separate_home).to eq false
    end

    it "sets 'enlarge_swap_for_suspend' based on the feature 'swap_for_suspend'" do
      read_feature("swap_for_suspend", true)
      expect(settings.enlarge_swap_for_suspend).to eq true
      read_feature("swap_for_suspend", false)
      expect(settings.enlarge_swap_for_suspend).to eq false
    end

    it "sets 'use_snapshots' based on the feature 'proposal_snapshots'" do
      read_feature("proposal_snapshots", true)
      expect(settings.use_snapshots).to eq true
      read_feature("proposal_snapshots", false)
      expect(settings.use_snapshots).to eq false
    end

    it "sets 'root_subvolume_read_only' based on the feature 'root_subvolume_read_only'" do
      read_feature("root_subvolume_read_only", true)
      expect(settings.root_subvolume_read_only).to eq true
      read_feature("root_subvolume_read_only", false)
      expect(settings.root_subvolume_read_only).to eq false
    end

    it "sets 'root_base_size' based on the feature 'root_base_size'" do
      read_feature("root_base_size", "111 GiB")
      expect(settings.root_base_size).to eq 111.GiB
    end

    it "sets 'root_max_size' based on the feature 'root_max_size'" do
      read_feature("root_max_size", "222 GiB")
      expect(settings.root_max_size).to eq 222.GiB
    end

    it "sets 'home_max_size' based on the feature 'vm_home_max_size'" do
      read_feature("vm_home_max_size", "333 GiB")
      expect(settings.home_max_size).to eq 333.GiB
    end

    it "sets 'min_size_to_use_separate_home' based on the feature 'limit_try_home'" do
      read_feature("limit_try_home", "444 GiB")
      expect(settings.min_size_to_use_separate_home).to eq 444.GiB
    end

    it "sets 'root_space_percent' based on the feature 'root_space_percent'" do
      read_feature("root_space_percent", "50")
      expect(settings.root_space_percent).to eq 50
      read_feature("root_space_percent", 80)
      expect(settings.root_space_percent).to eq 80
    end

    it "sets 'btrfs_increase_percentage' based on the feature 'btrfs_increase_percentage'" do
      read_feature("btrfs_increase_percentage", "150")
      expect(settings.btrfs_increase_percentage).to eq 150
      read_feature("btrfs_increase_percentage", 200)
      expect(settings.btrfs_increase_percentage).to eq 200
    end

    it "sets 'btrfs_default_subvolume' based on the feature 'btrfs_default_subvolume'" do
      read_feature("btrfs_default_subvolume", "@@@")
      expect(settings.btrfs_default_subvolume).to eq "@@@"
    end

    it "sets #subvolumes based on the list at the 'subvolumes' feature" do
      read_feature("subvolumes", [{ "path" => "home" }, { "path" => "opt" }])
      expect(settings.subvolumes.size).to eq 2
      expect(settings.subvolumes.map(&:path)).to contain_exactly("home", "opt")
    end

    context "when the 'partitioning' section is missing from the product features" do
      before do
        settings.use_lvm = true
        settings.root_base_size = 45.GiB

        stub_features("another_section" => { "value" => true })
      end

      it "does not modify any value" do
        settings.read_product_features!

        expect(settings.use_lvm).to eq true
        expect(settings.root_base_size).to eq 45.GiB
      end
    end

    context "when some features have a value and others don't" do
      let(:features) do
        {
          "proposal_snapshots" => false,
          "try_separate_home"  => true,
          "root_base_size"     => "60 GiB"
        }
      end

      before do
        settings.use_snapshots = true
        settings.use_lvm = true
        settings.use_separate_home = false
        settings.root_base_size = 45.GiB
        settings.root_max_size = 100.GiB

        stub_partitioning_features(features)
      end

      it "overrides previous values with the corresponding present features" do
        expect(settings.use_snapshots).to eq true
        expect(settings.use_separate_home).to eq false
        expect(settings.root_base_size).to eq 45.GiB

        settings.read_product_features!

        expect(settings.use_snapshots).to eq false
        expect(settings.use_separate_home).to eq true
        expect(settings.root_base_size).to eq 60.GiB
      end

      it "does not modify values corresponding to omitted features" do
        settings.read_product_features!

        expect(settings.use_lvm).to eq true
        expect(settings.root_max_size).to eq 100.GiB
      end
    end

    context "when reading a size" do
      let(:initial_size) { 14.GiB }

      before do
        settings.root_base_size = initial_size
      end

      it "can parse strings with spaces" do
        stub_partitioning_features("root_base_size" => "121 MiB ")
        settings.read_product_features!

        expect(settings.root_base_size).to eq 121.MiB
      end

      it "can parse strings without spaces" do
        stub_partitioning_features("root_base_size" => "121MiB")
        settings.read_product_features!

        expect(settings.root_base_size).to eq 121.MiB
      end

      it "parses the string assuming the units are always power of two" do
        stub_partitioning_features("root_base_size" => "121MB")
        settings.read_product_features!

        expect(settings.root_base_size).to_not eq 121.MB
        expect(settings.root_base_size).to eq 121.MiB
      end

      it "ignores values that are not a parseable size" do
        stub_partitioning_features("root_base_size" => "twelve")
        settings.read_product_features!

        expect(settings.root_base_size).to eq initial_size
      end

      it "ignores values equal to zero" do
        stub_partitioning_features("root_base_size" => "0 MiB")
        settings.read_product_features!

        expect(settings.root_base_size).to eq initial_size
      end
    end

    context "when reading an integer" do
      let(:initial_root_percent) { 10 }
      let(:initial_btrfs_percentage) { 100 }

      before do
        settings.root_space_percent = initial_root_percent
        settings.btrfs_increase_percentage = initial_btrfs_percentage
      end

      it "stores values greater than zero" do
        stub_partitioning_features("root_space_percent" => 1, "btrfs_increase_percentage" => "10000")
        settings.read_product_features!

        expect(settings.root_space_percent).to eq 1
        expect(settings.btrfs_increase_percentage).to eq 10000
      end

      it "stores values equal to zero" do
        stub_partitioning_features("root_space_percent" => 0, "btrfs_increase_percentage" => "0")
        settings.read_product_features!

        expect(settings.root_space_percent).to eq 0
        expect(settings.btrfs_increase_percentage).to eq 0
      end

      it "ignores negative values" do
        stub_partitioning_features("root_space_percent" => -5, "btrfs_increase_percentage" => "-12")
        settings.read_product_features!

        expect(settings.root_space_percent).to eq initial_root_percent
        expect(settings.btrfs_increase_percentage).to eq initial_btrfs_percentage
      end
    end

    context "when reading a boolean" do
      it "does not consider missing features to be false" do
        settings.use_lvm = true
        stub_partitioning_features("root_base_size" => "10 GiB")

        settings.read_product_features!
        expect(settings.use_lvm).to eq true
      end
    end

    context "when reading the 'subvolumes' feature" do
      before do
        allow(Yast::Arch).to receive(:x86_64).and_return true
        stub_partitioning_features("subvolumes" => subvols_feature)
      end

      let(:subvols_feature) do
        [
          { "path" => "home" },
          { "path" => "var", "copy_on_write" => false, "archs" => "i386,x86_64" },
          { "path" => "opt", "copy_on_write" => true },
          { "path" => "boot/efi", "archs" => "fake, ppc,  !  foo" }
        ]
      end
      let(:subvols) { settings.subvolumes }

      def subvol(name)
        subvols.detect { |s| s.path == name }
      end

      it "creates a SubvolSpecification for each subvolume in the list" do
        settings.read_product_features!
        expect(subvols.map(&:class)).to eq([Y2Storage::SubvolSpecification] * 4)
      end

      it "reads each 'path' value" do
        settings.read_product_features!
        expect(subvols.map(&:path)).to contain_exactly("boot/efi", "home", "opt", "var")
      end

      it "returns a list sorted by path" do
        settings.read_product_features!
        expect(subvols.map(&:path)).to eq ["boot/efi", "home", "opt", "var"]
      end

      it "reads each 'copy_on_write' value" do
        settings.read_product_features!
        expect(subvol("opt").copy_on_write).to eq true
        expect(subvol("var").copy_on_write).to eq false
      end

      it "uses true if 'copy_on_write' is omitted" do
        settings.read_product_features!
        expect(subvol("home").copy_on_write).to eq true
      end

      it "reads each 'archs' value as an array of strings" do
        settings.read_product_features!
        expect(subvol("var").archs).to contain_exactly("i386", "x86_64")
      end

      it "deals correctly with spaces in the 'archs' list" do
        settings.read_product_features!
        expect(subvol("boot/efi").archs).to contain_exactly("fake", "ppc", "!foo")
      end

      it "uses nil if 'archs' is omitted" do
        settings.read_product_features!
        expect(subvol("home").archs).to be_nil
      end

      context "for an empty list" do
        let(:subvols_feature) { [] }

        it "sets #subvolumes to an empty list" do
          settings.read_product_features!
          expect(subvols).to eq []
        end
      end

      context "if there is no 'subvolumes' feature" do
        let(:subvols_feature) { nil }

        it "sets #subvolumes to a fallback list" do
          allow(Y2Storage::SubvolSpecification).to receive(:fallback_list).and_return(["a", "list"])
          settings.read_product_features!

          expect(subvols).to eq ["a", "list"]
        end
      end

      context "if there are nil values in the list" do
        let(:subvols_feature) do
          [
            { "path" => "home" },
            nil,
            { "path" => "var" }
          ]
        end

        it "ignores the nil values" do
          settings.read_product_features!
          expect(subvols.size).to eq 2
          expect(subvols.map(&:path)).to contain_exactly("home", "var")
        end
      end

      context "if there are subvolumes without path" do
        let(:subvols_feature) do
          [
            { "path" => "home" },
            { "copy_on_write" => true }
          ]
        end

        it "ignores those subvolumes" do
          settings.read_product_features!
          expect(subvols.size).to eq 1
          expect(subvols.first.path).to eq "home"
        end
      end

      context "if there are several subvolumes with the same path" do
        let(:subvols_feature) do
          [
            { "path" => "var", "copy_on_write" => false, "archs" => "i386" },
            { "path" => "var" },
            { "path" => "var", "copy_on_write" => false }
          ]
        end

        # Filtering by architecture is done while calculating the proposal, not
        # when reading the specification
        it "does not verify the architecture at this point" do
          expect(Yast::Arch).to_not receive(:i386)
          settings.read_product_features!
        end

        it "creates a SubvolSpecification object for each one of the subvolumes" do
          settings.read_product_features!
          expect(subvols).to include(
            an_object_having_attributes(path: "var", copy_on_write: false, archs: ["i386"]),
            an_object_having_attributes(path: "var", copy_on_write: false, archs: nil),
            an_object_having_attributes(path: "var", copy_on_write: true,  archs: nil)
          )
        end
      end
    end
  end

  describe ".new_for_current_product" do
    subject(:from_product) { described_class.new_for_current_product }
    let(:default) { described_class.new }

    before do
      stub_partitioning_features(
        "proposal_lvm"       => true,
        "root_space_percent" => "50",
        "vm_home_max_size"   => "500 GiB"
      )
    end

    it "returns a new ProposalSettings object" do
      expect(from_product).to be_a described_class
    end

    it "returns an object that uses default values for the omitted features" do
      expect(from_product.use_separate_home).to eq default.use_separate_home
      expect(from_product.root_base_size).to eq default.root_base_size
      expect(from_product.btrfs_increase_percentage).to eq default.btrfs_increase_percentage
    end

    it "returns an object that uses the read values for the present features" do
      expect(from_product.use_lvm).to eq true
      expect(from_product.root_space_percent).to eq 50
      expect(from_product.home_max_size).to eq 500.GiB
    end
  end

  describe "the default (fallback) subvolumes list" do
    let(:default_settings) { described_class.new }

    it "includes a subvolume var/log" do
      expect(default_settings.subvolumes).to include(
        an_object_having_attributes(path: "var/log", copy_on_write: true, archs: nil)
      )
    end

    it "includes a NoCOW subvolume var/lib/mariadb" do
      expect(default_settings.subvolumes).to include(
        an_object_having_attributes(path: "var/lib/mariadb", copy_on_write: false, archs: nil)
      )
    end

    it "includes some arch-specific subvolumes for boot/*" do
      expect(default_settings.subvolumes).to include(
        an_object_having_attributes(
          path:          "boot/grub2/s390x-emu",
          copy_on_write: true,
          archs:         ["s390"]
        ),
        an_object_having_attributes(
          path:          "boot/grub2/x86_64-efi",
          copy_on_write: true,
          archs:         ["x86_64"]
        ),
        an_object_having_attributes(
          path:          "boot/grub2/powerpc-ieee1275",
          copy_on_write: true,
          archs:         ["ppc", "!board_powernv"]
        )
      )
    end
  end

  describe "#planned_subvolumes" do
    def subvol_spec(*args)
      Y2Storage::SubvolSpecification.new(*args)
    end

    subject(:settings) { described_class.new }

    before do
      allow(settings).to receive(:subvolumes).and_return subvol_specifications
    end

    let(:subvol_specifications) { [subvol_spec("var")] }

    it "returns an collection of Planned::BtrfsSubvolume objects" do
      expect(settings.planned_subvolumes).to all(be_a(Y2Storage::Planned::BtrfsSubvolume))
    end

    context "when 'archs' is an empty array" do
      let(:subvol_specifications) { [subvol_spec("var", archs: [])] }

      it "does not create the planned subvolume" do
        expect(settings.planned_subvolumes).to be_empty
      end
    end

    context "when 'archs' is nil" do
      let(:subvol_specifications) { [subvol_spec("var", archs: nil)] }

      it "creates the planned subvolume" do
        expect(settings.planned_subvolumes.map(&:path)).to contain_exactly("var")
      end
    end

    context "when 'archs' contains just one name" do
      let(:subvol_specifications) { [subvol_spec("var", archs: ["x86_64"])] }

      it "creates the planned subvolume if the architecture matches the name" do
        expect(Yast::Arch).to receive(:x86_64).and_return(true)
        expect(settings.planned_subvolumes.map(&:path)).to contain_exactly("var")
      end

      it "discards the subvolume if the architecture doesn't match" do
        expect(Yast::Arch).to receive(:x86_64).and_return(false)
        expect(settings.planned_subvolumes).to be_empty
      end
    end

    context "when 'archs' contains just one name preceded by '!'" do
      let(:subvol_specifications) { [subvol_spec("var", archs: ["!x86_64"])] }

      it "discards the subvolume if the architecture matches the name" do
        expect(Yast::Arch).to receive(:x86_64).and_return(true)
        expect(settings.planned_subvolumes).to be_empty
      end

      it "also discards the subvolume if the architecture doesn't match" do
        expect(Yast::Arch).to receive(:x86_64).and_return(false)
        expect(settings.planned_subvolumes).to be_empty
      end
    end

    context "when 'archs' contains a list of names" do
      let(:subvol_specifications) { [subvol_spec("var", archs: ["ppc", "x86_64"])] }

      it "creates the planned subvolume if the architecture matches any name" do
        expect(Yast::Arch).to receive(:ppc).and_return(false)
        expect(Yast::Arch).to receive(:x86_64).and_return(true)
        expect(settings.planned_subvolumes.map(&:path)).to contain_exactly("var")
      end

      it "discards the subvolume if none of the names matches the architecture" do
        expect(Yast::Arch).to receive(:ppc).and_return(false)
        expect(Yast::Arch).to receive(:x86_64).and_return(false)
        expect(settings.planned_subvolumes).to be_empty
      end
    end

    context "when 'archs' contains names with and without '!'" do
      let(:subvol_specifications) { [subvol_spec("var", archs: ["ppc", "!board_powernv"])] }

      it "creates the subvolume if the positive names match and the negated don't" do
        expect(Yast::Arch).to receive(:ppc).and_return(true)
        expect(Yast::Arch).to receive(:board_powernv).and_return(false)
        expect(settings.planned_subvolumes.map(&:path)).to contain_exactly("var")
      end

      it "discards the subvolume if both positive and negated names match" do
        expect(Yast::Arch).to receive(:ppc).and_return(true)
        expect(Yast::Arch).to receive(:board_powernv).and_return(true)
        expect(settings.planned_subvolumes).to be_empty
      end

      it "discards the subvolume if none of the positive names match" do
        expect(Yast::Arch).to receive(:ppc).and_return(false)
        expect(Yast::Arch).to receive(:board_powernv).and_return(false)
        expect(settings.planned_subvolumes).to be_empty
      end
    end

    context "if there are several subvolumes with the same path" do
      context "if only one of them apply to the current architecture" do
        let(:subvol_specifications) do
          [
            subvol_spec("var", copy_on_write: false, archs: ["i386"]),
            subvol_spec("var", copy_on_write: true)
          ]
        end

        before { expect(Yast::Arch).to receive(:i386).and_return(false) }

        it "just creates the relevant planned subvolume" do
          result = settings.planned_subvolumes
          expect(result.size).to eq 1
          expect(result.first).to have_attributes(path: "var", copy_on_write: true)
        end
      end

      context "if several of them apply to the current architecture" do
        let(:subvol_specifications) do
          [
            subvol_spec("var", copy_on_write: true, archs: ["i386"]),
            subvol_spec("var", copy_on_write: true),
            subvol_spec("var", copy_on_write: false)
          ]
        end

        before { expect(Yast::Arch).to receive(:i386).and_return(true) }

        it "just creates the last one to appear in the list" do
          result = settings.planned_subvolumes
          expect(result.size).to eq 1
          expect(result.first).to have_attributes(path: "var", copy_on_write: false)
        end
      end
    end
  end
end
