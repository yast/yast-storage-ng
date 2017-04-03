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
require "y2storage"

describe Y2Storage::Proposal::VolumesGenerator do
  describe "#all_volumes" do
    using Y2Storage::Refinements::SizeCasts

    # Just to shorten
    let(:xfs) { ::Storage::FsType_XFS }
    let(:vfat) { ::Storage::FsType_VFAT }
    let(:swap) { ::Storage::FsType_swap }
    let(:btrfs) { ::Storage::FsType_BTRFS }

    let(:settings) do
      # Set arch to s390 for subvolumes tests
      allow(Yast::Arch).to receive(:x86_64).and_return false
      allow(Yast::Arch).to receive(:s390).and_return true
      Y2Storage::ProposalSettings.new
    end
    let(:analyzer) { instance_double("Y2Storage::DiskAnalyzer") }
    let(:swap_partitions) { [] }
    let(:boot_checker) { instance_double("Y2Storage::BootRequirementChecker") }
    subject(:generator) { described_class.new(settings, analyzer) }

    before do
      allow(Y2Storage::BootRequirementsChecker).to receive(:new).and_return boot_checker
      allow(boot_checker).to receive(:needed_partitions).and_return(
        Y2Storage::PlannedVolumesList.new(
          [
            Y2Storage::PlannedVolume.new("/one_boot", xfs),
            Y2Storage::PlannedVolume.new("/other_boot", vfat)
          ]
        )
      )
      allow(analyzer).to receive(:swap_partitions).and_return("/dev/sda" => swap_partitions)
    end

    it "returns a list of volumes" do
      expect(subject.all_volumes).to be_a Y2Storage::PlannedVolumesList
    end

    it "includes the volumes needed by BootRequirementChecker" do
      expect(subject.all_volumes).to include(
        an_object_with_fields(mount_point: "/one_boot", filesystem_type: xfs),
        an_object_with_fields(mount_point: "/other_boot", filesystem_type: vfat)
      )
    end

    # This swap sizes are currently hard-coded
    context "swap volumes" do
      before do
        settings.enlarge_swap_for_suspend = false
      end

      let(:swap_volumes) { subject.all_volumes.select { |v| v.mount_point == "swap" } }

      context "if there is no previous swap partition" do
        let(:swap_partitions) { [] }

        it "includes a brand new swap volume and no swap reusing" do
          expect(swap_volumes).to contain_exactly(
            an_object_with_fields(reuse: nil)
          )
        end

        it "correctly sets the LVM properties for the new swap" do
          expect(swap_volumes).to contain_exactly(
            an_object_with_fields(plain_partition: false, logical_volume_name: "swap")
          )
        end
      end

      context "if the existing swap partition is not big enough" do
        let(:swap_partitions) { [analyzer_part("/dev/sdaX", 1.GiB)] }

        it "includes a brand new swap volume and no swap reusing" do
          expect(swap_volumes).to contain_exactly(
            an_object_with_fields(reuse: nil)
          )
        end
      end

      context "if the existing swap partition is big enough" do
        let(:swap_partitions) { [analyzer_part("/dev/sdaX", 3.GiB)] }

        context "if proposing an LVM setup" do
          before do
            settings.use_lvm = true
          end

          it "includes a brand new swap volume and no swap reusing" do
            expect(swap_volumes).to contain_exactly(
              an_object_with_fields(reuse: nil)
            )
          end
        end

        context "if proposing an partition-based setup" do
          context "without encryption" do
            it "includes a volume to reuse the existing swap and no new swap" do
              expect(swap_volumes).to contain_exactly(
                an_object_with_fields(reuse: "/dev/sdaX")
              )
            end
          end

          context "with encryption" do
            before do
              settings.encryption_password = "12345678"
            end

            it "includes a brand new swap volume and no swap reusing" do
              expect(swap_volumes).to contain_exactly(
                an_object_with_fields(reuse: nil)
              )
            end
          end
        end
      end

      context "without enlarge_swap_for_suspend" do
        it "plans a small swap volume" do
          expect(swap_volumes.first.min).to eq 2.GiB
          expect(swap_volumes.first.max).to eq 2.GiB
        end
      end

      context "with enlarge_swap_for_suspend" do
        before do
          settings.enlarge_swap_for_suspend = true
        end

        it "plans a bigger swap volume" do
          expect(swap_volumes.first.min).to eq 8.GiB
          expect(swap_volumes.first.max).to eq 8.GiB
        end
      end
    end

    context "with use_separate_home" do
      before do
        settings.use_separate_home = true
        settings.home_min_disk_size = 4.GiB
        settings.home_max_disk_size = Y2Storage::DiskSize.unlimited
        settings.home_filesystem_type = xfs
      end

      it "includes a /home volume with the configured settings" do
        expect(subject.all_volumes).to include(
          an_object_with_fields(
            mount_point:     "/home",
            min:             settings.home_min_disk_size,
            max:             settings.home_max_disk_size,
            filesystem_type: settings.home_filesystem_type
          )
        )
      end

      it "sets the LVM attributes for home" do
        home = subject.all_volumes.detect { |v| v.mount_point == "/home" }
        expect(home.logical_volume_name).to eq "home"
        expect(home.plain_partition?).to eq false
      end
    end

    context "without use_separate_home" do
      before do
        settings.use_separate_home = false
      end

      it "does not include a /home volume" do
        expect(subject.all_volumes).to_not include(
          an_object_with_fields(mount_point: "/home")
        )
      end
    end

    describe "setting the properties of the root partition" do
      before do
        settings.root_base_disk_size = 10.GiB
        settings.root_max_disk_size = 20.GiB
        settings.btrfs_increase_percentage = 75
      end

      it "sets the LVM attributes" do
        root = subject.all_volumes.detect { |v| v.mount_point == "/" }
        expect(root.logical_volume_name).to eq "root"
        expect(root.plain_partition?).to eq false
      end

      context "with a non-Btrfs filesystem" do
        before do
          settings.root_filesystem_type = xfs
        end

        it "uses the normal sizes" do
          expect(subject.all_volumes).to include(
            an_object_with_fields(
              mount_point:     "/",
              min:             10.GiB,
              max:             20.GiB,
              filesystem_type: xfs
            )
          )
        end
      end

      context "if Btrfs is used" do
        let(:root) { subject.all_volumes.detect { |v| v.mount_point == "/" } }
        before do
          settings.root_filesystem_type = btrfs
        end

        it "increases all the sizes by btrfs_increase_percentage" do
          expect(subject.all_volumes).to include(
            an_object_with_fields(
              mount_point:     "/",
              min:             17.5.GiB,
              max:             35.GiB,
              filesystem_type: btrfs
            )
          )
        end

        it "has subvolumes" do
          expect(root.subvolumes).not_to be_nil
          expect(root.subvolumes?).to be true
        end

        it "has a subvolume var/log" do
          expect(root.subvolumes).to include(
            an_object_with_fields(
              path:          "var/log",
              copy_on_write: true,
              archs:         nil
            )
          )
        end

        it "has a NoCOW subvolume var/lib/mariadb" do
          expect(root.subvolumes).to include(
            an_object_with_fields(
              path:          "var/lib/mariadb",
              copy_on_write: false,
              archs:         nil
            )
          )
        end

        it "has an arch-specific subvolume boot/grub2/s390x-emu on s390" do
          # Arch is s390 in these tests - see allow(Yast::Arch) in let(:settings)
          expect(root.subvolumes).to include(
            an_object_with_fields(
              path:          "boot/grub2/s390x-emu",
              copy_on_write: true,
              archs:         ["s390"]
            )
          )
        end

        it "does not have an arch-specific subvolume boot/grub2/x86_64-efi on s390" do
          # Arch is s390 in these tests - see allow(Yast::Arch) in let(:settings)
          expect(root.subvolumes).not_to include(
            an_object_with_fields(
              path:          "boot/grub2/x86_64-efi",
              copy_on_write: true,
              archs:         ["x86_64"]
            )
          )
        end
      end
    end
  end
end
