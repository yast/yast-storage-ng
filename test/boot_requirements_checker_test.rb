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
require "storage/proposal"
require "storage/boot_requirements_checker"
require "storage/refinements/size_casts"

def find_vol(mount_point, volumes)
  volumes.find {|p| p.mount_point == mount_point }
end

describe Yast::Storage::BootRequirementsChecker do
  describe "#needed_partitions" do
    using Yast::Storage::Refinements::SizeCasts

    subject(:checker) { described_class.new(settings, analyzer) }

    let(:settings) { Yast::Storage::Proposal::Settings.new }
    let(:analyzer) { instance_double("Yast::Storage::DiskAnalyzer") }
    let(:storage_arch) { instance_double("::Storage::Arch") }

    before do
      Yast::Storage::FakeProbing.new
      allow(Yast::Storage::StorageManager.instance).to receive(:arch).and_return(storage_arch)

      allow(storage_arch).to receive(:x86?).and_return(architecture == :x86)
      allow(storage_arch).to receive(:ppc64?).and_return(architecture == :ppc)
      allow(storage_arch).to receive(:s390?).and_return(architecture == :s390)
    end

    context "in a x86 system" do
      let(:architecture) { :x86 }

      before do
        allow(storage_arch).to receive(:efiboot?).and_return(efiboot)
      end

      context "using UEFI" do
        let(:efiboot) { true }

        before do
          allow(analyzer).to receive(:efi_partitions).and_return efi_partitions
        end

        context "with a partitions-based proposal" do
          before do
            settings.use_lvm = false
          end

          context "if there are no EFI partitions" do
            let(:efi_partitions) { [] }

            it "requires only a /boot/efi partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(mount_point: "/boot/efi")
              )
            end

            it "requires /boot/efi to be vfat with at least 33 MiB" do
              efi_part = find_vol("/boot/efi", checker.needed_partitions)
              expect(efi_part.filesystem_type).to eq ::Storage::FsType_VFAT
              expect(efi_part.min_size).to eq 33.MiB
            end

            it "recommends /boot/efi to be 500 MiB" do
              efi_part = find_vol("/boot/efi", checker.needed_partitions)
              expect(efi_part.desired_size).to eq 500.MiB
            end
          end

          context "if there is already an EFI partition" do
            let(:efi_partitions) { ["/dev/sda1"] }
          
            it "does not require any particular volume" do
              expect(checker.needed_partitions).to be_empty
            end
          end
        end

        context "with a LVM-based proposal" do
          before do
            settings.use_lvm = true
          end

          context "if there are no EFI partitions" do
            let(:efi_partitions) { [] }

            it "requires /boot and /boot/efi partitions" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(mount_point: "/boot"),
                an_object_with_fields(mount_point: "/boot/efi")
              )
            end

            it "requires /boot/efi to be vfat out of the LVM with at least 33 MiB" do
              efi_part = find_vol("/boot/efi", checker.needed_partitions)
              expect(efi_part.filesystem_type).to eq ::Storage::FsType_VFAT
              expect(efi_part.min_size).to eq 33.MiB
              expect(efi_part.can_live_on_logical_volume).to eq false
            end

            it "recommends /boot/efi to be 500 MiB" do
              efi_part = find_vol("/boot/efi", checker.needed_partitions)
              expect(efi_part.desired_size).to eq 500.MiB
            end

            it "requires /boot to be ext4 out of the LVM with at least 100 MiB" do
              efi_part = find_vol("/boot", checker.needed_partitions)
              expect(efi_part.filesystem_type).to eq ::Storage::FsType_EXT4
              expect(efi_part.min_size).to eq 100.MiB
              expect(efi_part.can_live_on_logical_volume).to eq false
            end

            it "recommends /boot to be 200 MiB" do
              efi_part = find_vol("/boot", checker.needed_partitions)
              expect(efi_part.desired_size).to eq 200.MiB
            end
          end

          context "if there is already an EFI partition" do
            let(:efi_partitions) { ["/dev/sda1"] }
          
            it "requires only a /boot partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(mount_point: "/boot")
              )
            end
          end
        end
      end

      context "not using UEFI (legacy PC)" do
        let(:efiboot) { false }

        context "with a partitions-based proposal" do
          before do
            settings.use_lvm = false
          end

          it "does not require any particular volume" do
            expect(checker.needed_partitions).to be_empty
          end
        end

        context "with a LVM-based proposal" do
          before do
            settings.use_lvm = true
          end

          it "requires only a /boot partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_with_fields(mount_point: "/boot")
            )
          end

          it "requires /boot to be ext4 out of the LVM with at least 100 MiB" do
            efi_part = find_vol("/boot", checker.needed_partitions)
            expect(efi_part.filesystem_type).to eq ::Storage::FsType_EXT4
            expect(efi_part.min_size).to eq 100.MiB
            expect(efi_part.can_live_on_logical_volume).to eq false
          end

          it "recommends /boot to be 200 MiB" do
            efi_part = find_vol("/boot", checker.needed_partitions)
            expect(efi_part.desired_size).to eq 200.MiB
          end
        end
      end
    end

    context "in a PPC64 system" do
      let(:arch) { :ppc64 }

      context "using KVM" do
        context "with a partitions-based proposal" do
        end

        context "with a LVM-based proposal" do
        end
      end

      context "using LPAR" do
        context "with a partitions-based proposal" do
        end

        context "with a LVM-based proposal" do
        end
      end

      context "in bare metal (PowerNV)" do
        context "with a partitions-based proposal" do
        end

        context "with a LVM-based proposal" do
        end
      end
    end
  end
end
