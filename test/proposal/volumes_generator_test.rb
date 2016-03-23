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

require_relative "../spec_helper"
require "storage"
require "storage/proposal"
require "storage/planned_volume"
require "storage/planned_volumes_list"
require "storage/refinements/size_casts"
require "storage/boot_requirements_checker"

describe Yast::Storage::Proposal::VolumesGenerator do
  describe "#volumes" do
    using Yast::Storage::Refinements::SizeCasts

    # Just to shorten
    let(:xfs) { ::Storage::FsType_XFS }
    let(:vfat) { ::Storage::FsType_VFAT }
    let(:swap) { ::Storage::FsType_swap }
    let(:btrfs) { ::Storage::FsType_BTRFS }

    let(:settings) { Yast::Storage::Proposal::Settings.new }
    let(:analyzer) { instance_double("Yast::Storage::DiskAnalyzer") }
    let(:boot_checker) { instance_double("Yast::Storage::BootRequirementChecker") }
    subject(:generator) { described_class.new(settings, analyzer) }

    before do
      allow(Yast::Storage::BootRequirementsChecker).to receive(:new).and_return boot_checker
      allow(boot_checker).to receive(:needed_partitions).and_return(
        Yast::Storage::PlannedVolumesList.new(
          [
            Yast::Storage::PlannedVolume.new("/one_boot", xfs),
            Yast::Storage::PlannedVolume.new("/other_boot", vfat)
          ]
        )
      )
    end

    it "returns a list of volumes" do
      expect(subject.volumes).to be_a Yast::Storage::PlannedVolumesList
    end

    it "includes the volumes needed by BootRequirementChecker" do
      expect(subject.volumes).to include(
        an_object_with_fields(mount_point: "/one_boot", filesystem_type: xfs),
        an_object_with_fields(mount_point: "/other_boot", filesystem_type: vfat)
      )
    end

    context "with enlarge_swap_for_suspend" do
      before do
        settings.enlarge_swap_for_suspend = true
      end

      it "includes a big swap volume" do
        expect(subject.volumes).to include(
          # This value is currently hard-coded
          an_object_with_fields(mount_point: "swap", min_size: 8.GiB, max_size: 8.GiB)
        )
      end
    end

    context "without enlarge_swap_for_suspend" do
      before do
        settings.enlarge_swap_for_suspend = false
      end

      it "includes a small swap volume" do
        expect(subject.volumes).to include(
          # This value is currently hard-coded
          an_object_with_fields(mount_point: "swap", min_size: 2.GiB, max_size: 2.GiB)
        )
      end
    end

    context "with use_separate_home" do
      before do
        settings.use_separate_home = true
        settings.home_min_size = 4.GiB
        settings.home_max_size = Yast::Storage::DiskSize.unlimited
        settings.home_filesystem_type = xfs
      end

      it "includes a /home volume with the configured settings" do
        expect(subject.volumes).to include(
          an_object_with_fields(
            mount_point:     "/home",
            min_size:        settings.home_min_size,
            max_size:        settings.home_max_size,
            filesystem_type: settings.home_filesystem_type
          )
        )
      end
    end

    context "without use_separate_home" do
      before do
        settings.use_separate_home = false
      end

      it "does not include a /home volume" do
        expect(subject.volumes).to_not include(
          an_object_with_fields(mount_point: "/home")
        )
      end
    end

    describe "setting the size of the root partition" do
      before do
        settings.root_base_size = 10.GiB
        settings.root_max_size = 20.GiB
        settings.btrfs_increase_percentage = 75
      end

      context "with a non-Btrfs filesystem" do
        before do
          settings.root_filesystem_type = xfs
        end

        it "uses the normal sizes" do
          expect(subject.volumes).to include(
            an_object_with_fields(
              mount_point:     "/",
              min_size:        10.GiB,
              max_size:        20.GiB,
              filesystem_type: xfs
            )
          )
        end
      end

      context "if Btrfs is used" do
        before do
          settings.root_filesystem_type = btrfs
        end

        it "increases all the sizes by btrfs_increase_percentage" do
          expect(subject.volumes).to include(
            an_object_with_fields(
              mount_point:     "/",
              min_size:        17.5.GiB,
              max_size:        35.GiB,
              filesystem_type: btrfs
            )
          )
        end
      end
    end
  end
end
