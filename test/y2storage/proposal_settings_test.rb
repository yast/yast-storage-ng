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

  # Other test are using ProposalSettings#new_for_current_product to initialize
  # the settings. That method sets some default values when there is not
  # imported features (i.e., when control.xml is not found).
  #
  # Due to the tests rely on settings with pristine default values, it is necessary
  # to reset the product features to not interfer in other tests.
  after(:all) do
    Yast::ProductFeatures.Import({})
  end

  def stub_features(all_features)
    Yast::ProductFeatures.Import(all_features)
  end

  def stub_partitioning_features(features = {})
    stub_features("partitioning" => initial_partitioning_features.merge(features))
  end

  let(:initial_partitioning_features) { {} }

  describe "#for_current_product" do
    subject(:settings) { described_class.new }

    context "when the 'partitioning' section is missing from the product features" do
      before do
        stub_features("another_section" => { "value" => true })

        settings.use_lvm = true
        settings.root_base_size = 45.GiB
      end

      it "sets format to :legacy" do
        settings.for_current_product
        expect(settings.format).to eq(Y2Storage::ProposalSettings::LEGACY_FORMAT)
      end

      it "does not modify initalized settings" do
        settings.for_current_product

        expect(settings.use_lvm).to eq true
        expect(settings.root_base_size).to eq 45.GiB
      end

      it "sets not initalized settings with default values" do
        settings.for_current_product

        expect(settings.root_max_size).to eq(10.GiB)
        expect(settings.root_filesystem_type).to eq(Y2Storage::Filesystems::Type::BTRFS)
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

        settings.for_current_product

        expect(settings.use_snapshots).to eq false
        expect(settings.use_separate_home).to eq true
        expect(settings.root_base_size).to eq 60.GiB
      end

      it "does not modify values corresponding to omitted features" do
        settings.for_current_product

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
        settings.for_current_product

        expect(settings.root_base_size).to eq 121.MiB
      end

      it "can parse strings without spaces" do
        stub_partitioning_features("root_base_size" => "121MiB")
        settings.for_current_product

        expect(settings.root_base_size).to eq 121.MiB
      end

      it "parses the string assuming the units are always power of two" do
        stub_partitioning_features("root_base_size" => "121MB")
        settings.for_current_product

        expect(settings.root_base_size).to_not eq 121.MB
        expect(settings.root_base_size).to eq 121.MiB
      end

      it "ignores values that are not a parseable size" do
        stub_partitioning_features("root_base_size" => "twelve")
        settings.for_current_product

        expect(settings.root_base_size).to eq initial_size
      end

      it "ignores values equal to zero" do
        stub_partitioning_features("root_base_size" => "0 MiB")
        settings.for_current_product

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
        settings.for_current_product

        expect(settings.root_space_percent).to eq 1
        expect(settings.btrfs_increase_percentage).to eq 10000
      end

      it "stores values equal to zero" do
        stub_partitioning_features("root_space_percent" => 0, "btrfs_increase_percentage" => "0")
        settings.for_current_product

        expect(settings.root_space_percent).to eq 0
        expect(settings.btrfs_increase_percentage).to eq 0
      end

      it "ignores negative values" do
        stub_partitioning_features("root_space_percent" => -5, "btrfs_increase_percentage" => "-12")
        settings.for_current_product

        expect(settings.root_space_percent).to eq initial_root_percent
        expect(settings.btrfs_increase_percentage).to eq initial_btrfs_percentage
      end
    end

    context "when reading a boolean" do
      it "does not consider missing features to be false" do
        settings.use_lvm = true
        stub_partitioning_features("root_base_size" => "10 GiB")

        settings.for_current_product
        expect(settings.use_lvm).to eq true
      end
    end

    context "when the 'partitioning' section has legacy format" do
      let(:initial_partitioning_features) { {} }

      def read_feature(feature, value)
        stub_partitioning_features(feature => value)
        settings.for_current_product
      end

      it "sets format to :legacy" do
        stub_partitioning_features
        settings.for_current_product
        expect(settings.format).to eq(Y2Storage::ProposalSettings::LEGACY_FORMAT)
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

      it "does not set ng settings" do
        expect(settings.lvm).to be_nil
        expect(settings.lvm_vg_strategy).to be_nil
        expect(settings.lvm_vg_size).to be_nil
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
          settings.for_current_product
          expect(subvols.map(&:class)).to eq([Y2Storage::SubvolSpecification] * 4)
        end

        it "reads each 'path' value" do
          settings.for_current_product
          expect(subvols.map(&:path)).to contain_exactly("boot/efi", "home", "opt", "var")
        end

        it "returns a list sorted by path" do
          settings.for_current_product
          expect(subvols.map(&:path)).to eq ["boot/efi", "home", "opt", "var"]
        end

        it "reads each 'copy_on_write' value" do
          settings.for_current_product
          expect(subvol("opt").copy_on_write).to eq true
          expect(subvol("var").copy_on_write).to eq false
        end

        it "uses true if 'copy_on_write' is omitted" do
          settings.for_current_product
          expect(subvol("home").copy_on_write).to eq true
        end

        it "reads each 'archs' value as an array of strings" do
          settings.for_current_product
          expect(subvol("var").archs).to contain_exactly("i386", "x86_64")
        end

        it "deals correctly with spaces in the 'archs' list" do
          settings.for_current_product
          expect(subvol("boot/efi").archs).to contain_exactly("fake", "ppc", "!foo")
        end

        it "uses nil if 'archs' is omitted" do
          settings.for_current_product
          expect(subvol("home").archs).to be_nil
        end

        context "for an empty list" do
          let(:subvols_feature) { [] }

          it "sets #subvolumes to an empty list" do
            settings.for_current_product
            expect(subvols).to eq []
          end
        end

        context "if there is no 'subvolumes' feature" do
          let(:subvols_feature) { nil }

          it "sets #subvolumes to a fallback list" do
            allow(Y2Storage::SubvolSpecification).to receive(:fallback_list).and_return(["a", "list"])
            settings.for_current_product

            expect(subvols).to eq ["a", "list"]
          end

          it "includes a subvolume var/log" do
            settings.for_current_product

            expect(subvols).to include(
              an_object_having_attributes(path: "var/log", copy_on_write: true, archs: nil)
            )
          end

          it "includes a NoCOW subvolume var/lib/mariadb" do
            settings.for_current_product

            expect(subvols).to include(
              an_object_having_attributes(path: "var/lib/mariadb", copy_on_write: false, archs: nil)
            )
          end

          it "includes some arch-specific subvolumes for boot/*" do
            settings.for_current_product

            expect(subvols).to include(
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

        context "if there are nil values in the list" do
          let(:subvols_feature) do
            [
              { "path" => "home" },
              nil,
              { "path" => "var" }
            ]
          end

          it "ignores the nil values" do
            settings.for_current_product
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
            settings.for_current_product
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
            settings.for_current_product
          end

          it "creates a SubvolSpecification object for each one of the subvolumes" do
            settings.for_current_product
            expect(subvols).to include(
              an_object_having_attributes(path: "var", copy_on_write: false, archs: ["i386"]),
              an_object_having_attributes(path: "var", copy_on_write: false, archs: nil),
              an_object_having_attributes(path: "var", copy_on_write: true,  archs: nil)
            )
          end
        end
      end
    end

    context "when the partitioning section has :ng format" do
      let(:initial_partitioning_features) do
        { "proposal" => proposal_features, "volumes" => volumes_features }
      end

      let(:proposal_features) { {} }

      let(:volumes_features) { [] }

      def read_feature(feature, value)
        stub_partitioning_features("proposal" => { feature => value })
        settings.for_current_product
      end

      it "sets format to :ng" do
        stub_partitioning_features
        settings.for_current_product
        expect(settings.format).to eq(Y2Storage::ProposalSettings::NG_FORMAT)
      end

      it "sets 'lvm' based on the feature in the 'proposal' section" do
        read_feature("lvm", true)
        expect(settings.lvm).to eq true
        read_feature("lvm", false)
        expect(settings.lvm).to eq false
      end

      it "sets 'resize_windows' based on the feature in the 'proposal' section" do
        read_feature("resize_windows", true)
        expect(settings.resize_windows).to eq true
        read_feature("resize_windows", false)
        expect(settings.resize_windows).to eq false
      end

      it "sets 'windows_delete_mode' based on the feature in the 'proposal' section" do
        read_feature("windows_delete_mode", :none)
        expect(settings.windows_delete_mode).to eq :none
        read_feature("windows_delete_mode", :ondemand)
        expect(settings.windows_delete_mode).to eq :ondemand
      end

      it "sets 'linux_delete_mode' based on the feature in the 'proposal' section" do
        read_feature("linux_delete_mode", :none)
        expect(settings.linux_delete_mode).to eq :none
        read_feature("linux_delete_mode", :ondemand)
        expect(settings.linux_delete_mode).to eq :ondemand
      end

      it "sets 'other_delete_mode' based on the feature in the 'proposal' section" do
        read_feature("other_delete_mode", :none)
        expect(settings.other_delete_mode).to eq :none
        read_feature("other_delete_mode", :ondemand)
        expect(settings.other_delete_mode).to eq :ondemand
      end

      it "sets 'lvm_vg_strategy' based on the feature in the 'proposal' section" do
        read_feature("lvm_vg_strategy", :use_available)
        expect(settings.lvm_vg_strategy).to eq :use_available
        read_feature("lvm_vg_strategy", :use_needed)
        expect(settings.lvm_vg_strategy).to eq :use_needed
      end

      it "sets 'lvm_vg_size' based on the feature in the 'proposal' section" do
        read_feature("lvm_vg_size", "1 GiB")
        expect(settings.lvm_vg_size).to eq 1.GiB
        read_feature("lvm_vg_size", "5 MiB")
        expect(settings.lvm_vg_size).to eq 5.MiB
      end

      context "when reading the 'volumes' section" do
        before do
          stub_partitioning_features
        end

        context "and the list of volumes is empty" do
          let(:volumes_features) { [] }

          it "returns an empty list of volumes" do
            settings.for_current_product
            expect(settings.volumes).to be_empty
          end
        end

        context "and the list of volumes is not empty" do
          let(:volumes_features) do
            [{ "mount_point" => "/" }, { "mount_point" => "/home", "min_size" => "5 GiB" }]
          end

          it "creates a VolumeSpecification for each volume in the list" do
            settings.for_current_product
            expect(settings.volumes.map(&:class)).to eq([Y2Storage::VolumeSpecification] * 2)
          end
        end
      end
    end
  end

  describe ".new_for_current_product" do
    subject(:from_product) { described_class.new_for_current_product }

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
      expect(from_product.use_separate_home).to eq(true)
      expect(from_product.root_base_size).to eq(3.GiB)
      expect(from_product.btrfs_increase_percentage).to eq(300.0)
    end

    it "returns an object that uses the read values for the present features" do
      expect(from_product.use_lvm).to eq true
      expect(from_product.root_space_percent).to eq 50
      expect(from_product.home_max_size).to eq 500.GiB
    end
  end

  describe "#snapshots_active?" do
    context "when the format is :legacy" do
      subject(:settings) { described_class.new }

      before do
        allow(settings).to receive(:root_filesystem_type).and_return(root_filesystem)
        allow(settings).to receive(:use_snapshots).and_return(snapshots)
      end

      let(:snapshots) { false }

      context "when root filesystem is not btrfs" do
        let(:root_filesystem) { Y2Storage::Filesystems::Type::EXT4 }

        it "returns false" do
          expect(settings.snapshots_active?).to eq false
        end
      end

      context "when root filesystem is btrfs" do
        let(:root_filesystem) { Y2Storage::Filesystems::Type::BTRFS }

        context "and it is not using snapshots" do
          let(:snapshots) { false }

          it "returns false" do
            expect(settings.snapshots_active?).to eq false
          end
        end

        context "and it is using snapshots" do
          let(:snapshots) { true }

          it "returns true" do
            expect(settings.snapshots_active?).to eq true
          end
        end
      end
    end

    context "when the format is :ng" do
      let(:initial_partitioning_features) { { "proposal" => [], "volumes" => volumes_features } }

      let(:settings) { described_class.new_for_current_product }

      before do
        stub_partitioning_features
      end

      context "and there is not a root volume" do
        let(:volumes_features) { [{ "mount_point" => "/home", "snapshots" => true }] }

        it "returns false" do
          expect(settings.snapshots_active?).to eq(false)
        end
      end

      context "and there is a root volume" do
        let(:volumes_features) { [{ "mount_point" => "/", "snapshots" => snapshots }] }

        context "and snapshots feature is not active" do
          let(:snapshots) { false }

          it "returns false" do
            expect(settings.snapshots_active?).to eq(false)
          end
        end

        context "and snapshots feature is active" do
          let(:snapshots) { true }

          it "returns true" do
            expect(settings.snapshots_active?).to eq(true)
          end
        end
      end
    end
  end

  describe "#to_s" do
    subject(:settings) { described_class.new_for_current_product }

    before do
      stub_partitioning_features
    end

    context "when the format is :legacy" do
      let(:initial_partitioning_features) { {} }

      it "generates a string representation for legacy format" do
        expect(settings.to_s).to match("(legacy)")
      end
    end

    context "when the format is :ng" do
      let(:initial_partitioning_features) { { "proposal" => [], "volumes" => {} } }

      it "generates a string representation for ng format" do
        expect(settings.to_s).to match("(ng)")
      end
    end
  end
end
