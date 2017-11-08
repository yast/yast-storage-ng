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

describe Y2Storage::VolumeSpecification do
  using Y2Storage::Refinements::SizeCasts

  subject { described_class.new(volume_features) }

  describe "#initialize" do
    let(:volume_features) do
      {
        "mount_point"                => mount_point,
        "proposed"                   => proposed,
        "proposed_configurable"      => proposed_configurable,
        "desired_size"               => desired_size,
        "min_size"                   => min_size,
        "max_size"                   => max_size,
        "max_size_lvm"               => max_size_lvm,
        "weight"                     => weight,
        "adjust_by_ram"              => adjust_by_ram,
        "adjust_by_ram_configurable" => adjust_by_ram_configurable,
        "snapshots"                  => snapshots,
        "snapshots_configurable"     => snapshots_configurable,
        "snapshots_size"             => snapshots_size,
        "snapshots_percentage"       => snapshots_percentage,
        "fs_type"                    => fs_type,
        "fs_types"                   => fs_types
      }
    end

    let(:mount_point) { "/home" }
    let(:proposed) { true }
    let(:proposed_configurable) { true }
    let(:desired_size) { "5 GiB" }
    let(:min_size) { "3 GiB" }
    let(:max_size) { "15 GiB" }
    let(:max_size_lvm) { "10 GiB" }
    let(:weight) { 20 }
    let(:adjust_by_ram) { true }
    let(:adjust_by_ram_configurable) { false }
    let(:snapshots) { true }
    let(:snapshots_configurable) { true }
    let(:snapshots_size) { "10 GiB" }
    let(:snapshots_percentage) { 10 }
    let(:fs_type) { nil }
    let(:fs_types) { nil }

    it "creates an object with the indicated features" do
      expect(subject.mount_point).to eq("/home")
      expect(subject.proposed).to eq(true)
      expect(subject.proposed_configurable).to eq(true)
      expect(subject.desired_size).to eq(5.GiB)
      expect(subject.min_size).to eq(3.GiB)
      expect(subject.max_size).to eq(15.GiB)
      expect(subject.max_size_lvm).to eq(10.GiB)
      expect(subject.weight).to eq(20)
      expect(subject.adjust_by_ram).to eq(true)
      expect(subject.adjust_by_ram_configurable).to eq(false)
      expect(subject.snapshots).to eq(true)
      expect(subject.snapshots_configurable).to eq(true)
      expect(subject.snapshots_size).to eq(10.GiB)
      expect(subject.snapshots_percentage).to eq(10)
    end

    context "when 'proposed' is not indicated" do
      let(:proposed) { nil }

      it "sets 'proposed' to true by default" do
        expect(subject.proposed).to eq(true)
      end
    end

    context "when 'proposed_configurable' is not indicated" do
      let(:proposed_configurable) { nil }

      it "sets 'proposed_configurable' to false by default" do
        expect(subject.proposed_configurable).to eq(false)
      end
    end

    context "when 'desired_size' is not indicated" do
      let(:desired_size) { nil }

      it "sets 'desired_size' to 0 by default" do
        expect(subject.desired_size).to eq(Y2Storage::DiskSize.zero)
      end
    end

    context "when 'min_size' is not indicated" do
      let(:min_size) { nil }

      it "sets 'min_size' to 0 by default" do
        expect(subject.min_size).to eq(Y2Storage::DiskSize.zero)
      end
    end

    context "when 'max_size' is not indicated" do
      let(:max_size) { nil }

      it "sets 'max_size' to unlimited by default" do
        expect(subject.max_size).to eq(Y2Storage::DiskSize.unlimited)
      end
    end

    context "when 'max_size_lvm' is not indicated" do
      let(:max_size_lvm) { nil }

      it "sets 'max_size_lvm' to 0 by default" do
        expect(subject.max_size_lvm).to eq(Y2Storage::DiskSize.zero)
      end
    end

    context "when 'weight' is not indicated" do
      let(:weight) { nil }

      it "sets 'weight' to 0 by default" do
        expect(subject.weight).to eq(0)
      end
    end

    context "when 'adjust_by_ram' is not indicated" do
      let(:adjust_by_ram) { nil }

      it "sets 'adjust_by_ram' to false by default" do
        expect(subject.adjust_by_ram).to eq(false)
      end
    end

    context "when 'adjust_by_ram_configurable' is not indicated" do
      let(:adjust_by_ram_configurable) { nil }

      it "sets 'adjust_by_ram_configurable' to false by default" do
        expect(subject.adjust_by_ram_configurable).to eq(false)
      end
    end

    context "when 'snapshots' is not indicated" do
      let(:snapshots) { nil }

      it "sets 'snapshots' to false by default" do
        expect(subject.snapshots).to eq(false)
      end
    end

    context "when 'snapshots_configurable' is not indicated" do
      let(:snapshots_configurable) { nil }

      it "sets 'snapshots_configurable' to false by default" do
        expect(subject.snapshots_configurable).to eq(false)
      end
    end

    context "when 'snapshots_size' is not indicated" do
      let(:snapshots_size) { nil }

      it "sets 'snapshots_size' to 0 by default" do
        expect(subject.snapshots_size).to eq(Y2Storage::DiskSize.zero)
      end
    end

    context "when 'snapshots_percentage' is not indicated" do
      let(:snapshots_percentage) { nil }

      it "sets 'snapshots_percentage' to 0 by default" do
        expect(subject.snapshots_percentage).to eq(0)
      end
    end

    context "when 'fs_type' is not indicated" do
      let(:fs_type) { nil }

      it "does not set 'fs_type'" do
        expect(subject.fs_type).to be_nil
      end
    end

    context "when a fs_type is indicated" do
      let(:fs_type) { fs_type }

      context "and fs_type is valid" do
        let(:fs_type) { :ext3 }

        it "sets the proper Filesystems::Type" do
          type = Y2Storage::Filesystems::Type.find(:ext3)
          expect(subject.fs_type).to eq(type)
        end
      end

      context "and fs_type is not valid" do
        let(:fs_type) { :foo }

        it "raises an exception" do
          expect { subject }.to raise_error(NameError)
        end
      end
    end

    context "when the list of fs_types is not indicated" do
      let(:fs_types) { nil }

      context "and a fs_type is indicated" do
        let(:fs_type) { :ntfs }

        it "includes the fs_type" do
          expect(subject.fs_types).to include(Y2Storage::Filesystems::Type::NTFS)
        end
      end

      context "and the volume is root" do
        let(:mount_point) { "/" }

        it "sets a fallback list of fs_types for root" do
          expect(subject.fs_types).to eq(Y2Storage::Filesystems::Type.root_filesystems)
        end
      end

      context "and the volume is home" do
        let(:mount_point) { "/home" }

        it "sets a fallback list of fs_types for home" do
          expect(subject.fs_types).to eq(Y2Storage::Filesystems::Type.home_filesystems)
        end
      end

      context "and the volume is neither root nor home" do
        let(:mount_point) { "/tmp" }

        context "and a fs_type is indicated" do
          let(:fs_type) { :ext3 }

          it "sets a list with that fs_type" do
            expect(subject.fs_types).to eq([Y2Storage::Filesystems::Type::EXT3])
          end
        end

        context "and a fs_type is not indicated" do
          let(:fs_type) { nil }

          it "sets an emtpy list" do
            expect(subject.fs_types).to be_empty
          end
        end
      end
    end

    context "when a list of fs_types is indicated" do
      context "and all of them are valid types" do
        let(:fs_types) { ["ext3", "xfs", "btrfs"] }

        it "sets a list of proper Filesystems::Type" do
          types = [:ext3, :xfs, :btrfs].map { |t| Y2Storage::Filesystems::Type.find(t) }
          expect(subject.fs_types).to eq(types)
        end

        context "and a fs_type is indicated" do
          let(:fs_type) { :ntfs }

          it "includes the fs_type" do
            expect(subject.fs_types).to include(Y2Storage::Filesystems::Type::NTFS)
          end
        end
      end

      context "and it contains some not valid type" do
        let(:fs_types) { ["ext3", "foo", "btrfs"] }

        it "raises an exception" do
          expect { subject }.to raise_error(NameError)
        end
      end
    end

    context "when the list of subvolumes is not indicated" do
      let(:volume_features) { { "mount_point" => mount_point } }

      context "and the volume is not root" do
        let(:mount_point) { "/home" }

        it "sets an empty list of subvolumes" do
          expect(subject.subvolumes).to be_empty
        end
      end

      context "and the volume is root" do
        let(:mount_point) { "/" }

        it "sets a fallback list of subvolumes" do
          expect(subject.subvolumes).to_not be_empty
          expect(subject.subvolumes).to all(be_a(Y2Storage::SubvolSpecification))
        end
      end
    end

    context "when a list of subvolumes is indicated" do
      let(:volume_features) { { "mount_point" => mount_point, "subvolumes" => subvolumes } }

      context "and the list is empty" do
        let(:subvolumes) { [] }

        context "and the volume is not root" do
          let(:mount_point) { "/home" }

          it "sets an empty list of subvolumes" do
            expect(subject.subvolumes).to be_empty
          end
        end

        context "and the volume is root" do
          let(:mount_point) { "/" }

          it "sets an empty list of subvolumes" do
            expect(subject.subvolumes).to be_empty
          end
        end
      end

      context "and the list is not empty" do
        let(:mount_point) { "/home" }

        let(:subvolumes) do
          [
            { "path" => "home" },
            { "path" => "var", "copy_on_write" => false, "archs" => "i386,x86_64" },
            { "path" => "opt", "copy_on_write" => true }
          ]
        end

        it "sets the indicated list of subvolumes" do
          expect(subject.subvolumes).to include(
            an_object_having_attributes(path: "home", copy_on_write: true, archs: nil),
            an_object_having_attributes(path: "var", copy_on_write: false, archs: ["i386", "x86_64"]),
            an_object_having_attributes(path: "opt", copy_on_write: true,  archs: nil)
          )
        end
      end
    end
  end
end
