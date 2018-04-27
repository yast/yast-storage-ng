#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

describe Y2Storage::BootRequirementsChecker do
  using Y2Storage::Refinements::SizeCasts

  subject(:checker) { described_class.new(fake_devicegraph) }

  let(:power_nv) { false }
  let(:efiboot) { false }
  let(:scenario) { "trivial" }
  let(:architecture) { :x86_64 }

  before do
    fake_scenario(scenario)

    storage_arch = double("::Storage::Arch")
    allow(Y2Storage::StorageManager.instance).to receive(:arch).and_return(storage_arch)

    allow(storage_arch).to receive(:x86?).and_return(architecture == :x86)
    allow(storage_arch).to receive(:ppc?).and_return(architecture == :ppc)
    allow(storage_arch).to receive(:s390?).and_return(architecture == :s390)
    allow(storage_arch).to receive(:efiboot?).and_return(efiboot)
    allow(storage_arch).to receive(:ppc_power_nv?).and_return(power_nv)
  end

  describe "#valid?" do
    let(:errors) { [] }
    let(:warnings) { [] }

    before do
      allow(checker).to receive(:errors).and_return(errors)
      allow(checker).to receive(:warnings).and_return(warnings)
    end

    context "when there are errors" do
      let(:errors) { [Y2Storage::SetupError.new(message: "test")] }

      it "returns false" do
        expect(checker.valid?).to eq(false)
      end
    end

    context "when there are warnings" do
      let(:warnings) { [Y2Storage::SetupError.new(message: "test")] }

      it "returns false" do
        expect(checker.valid?).to eq(false)
      end
    end

    context "when there are no errors neither warnings" do
      let(:errors) { [] }
      let(:warnings) { [] }

      it "returns true" do
        expect(checker.valid?).to eq(true)
      end
    end
  end

  describe "#errors" do
    RSpec.shared_examples "no errors" do
      it "does not contain an error" do
        expect(checker.warnings).to be_empty
      end
    end

    RSpec.shared_examples "missing boot partition" do
      it "contains an error for missing boot partition" do
        expect(checker.warnings.size).to eq(1)
        expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

        message = checker.warnings.first.message
        expect(message).to match(/Missing device for \/boot/)
      end
    end

    RSpec.shared_examples "missing prep partition" do
      it "contains an error for missing PReP partition" do
        expect(checker.warnings.size).to eq(1)
        expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

        message = checker.warnings.first.message
        expect(message).to match(/Missing device.* partition id prep/)
      end
    end

    RSpec.shared_examples "missing zipl partition" do
      it "contains an error for missing ZIPL partition" do
        expect(checker.warnings.size).to eq(1)
        expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

        msg = checker.warnings.first.message
        expect(msg).to match(/Missing device for \/boot\/zipl/)
      end
    end

    RSpec.shared_examples "unknown boot disk" do
      it "contains an fatal error for unknown boot disk" do
        expect(checker.errors.size).to eq(1)
        expect(checker.errors).to all(be_a(Y2Storage::SetupError))

        message = checker.errors.first.message
        expect(message).to match(/no device mounted at '\/'/)
      end
    end

    RSpec.shared_examples "unsupported boot disk" do
      it "contains an error for unsupported boot disk" do
        expect(checker.warnings.size).to eq(1)
        expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

        message = checker.warnings.first.message
        expect(message).to match(/is not supported/)
      end
    end

    RSpec.shared_examples "efi partition" do
      context "when there is no /boot/efi partition in the system" do
        let(:scenario) { "trivial" }

        it "contains an error for the efi partition" do
          expect(checker.warnings.size).to eq(1)
          expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

          message = checker.warnings.first.message
          expect(message).to match(/Missing device for \/boot\/efi/)
        end
      end

      context "when there is a /boot/efi partition in the system" do
        let(:scenario) { "efi" }

        include_examples("no errors")
      end
    end

    let(:efiboot) { false }

    context "/boot is too small" do
      let(:scenario) { "small_boot" }

      before do
        allow_any_instance_of(Y2Storage::Filesystems::BlkFilesystem).to receive(:detect_space_info)
          .and_return(double(free: Y2Storage::DiskSize.MiB(1)))
      end

      it "contains an error when there is /boot that is not big enough" do
        expect(checker.errors.size).to eq(1)
        expect(checker.errors).to all(be_a(Y2Storage::SetupError))

        message = checker.errors.first.message
        expect(message).to match(/does not have enough space/)
      end
    end

    context "in a x86 system" do
      let(:architecture) { :x86 }

      context "using UEFI" do
        let(:efiboot) { true }
        include_examples "efi partition"

        context "/boot/efi lays on md raid level 1" do
          let(:scenario) { "raid_efi.xml" }

          it "contains warning" do
            expect(checker.warnings.size).to eq(1)
            expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

            message = checker.warnings.first.message
            expect(message).to match(/\/boot\/efi.*software RAID/)
          end
        end
      end

      context "not using UEFI (legacy PC)" do
        let(:efiboot) { false }

        context "when there is no root" do
          let(:scenario) { "false-swaps" }
          include_examples "unknown boot disk"
        end

        context "when boot device has a GPT partition table" do
          context "and there is no a grub partition in the system" do
            let(:scenario) { "gpt_without_grub" }

            it "contains an error for missing grub partition" do
              expect(checker.warnings.size).to eq(1)
              expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

              message = checker.warnings.first.message
              expect(message).to match(/Missing device.*partition id bios_boot/)
            end
          end

          context "and there is a grub partition in the system" do
            it "does not contain errors" do
              expect(checker.warnings).to be_empty
            end
          end
        end

        context "with a MS-DOS partition table" do
          context "with a too small MBR gap" do
            before do
              # it have to be set here, as mbr_gap in yml set only minimal size and not real one
              allow(checker.send(:strategy).boot_disk).to receive(:mbr_gap).and_return(0.KiB)
            end

            context "in a plain btrfs setup" do
              let(:scenario) { "dos_btrfs" }

              include_examples "no errors"
            end

            context "in a not plain btrfs setup" do
              let(:scenario) { "dos_lvm" }

              it "contains an error for small MBR gap" do
                expect(checker.warnings.size).to eq(1)
                expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

                message = checker.warnings.first.message
                expect(message).to match(/gap size is not enough/)
              end
            end
          end

          context "if the MBR gap is big enough to embed Grub" do
            before do
              # it have to be set here, as mbr_gap in yml set only minimal size and not real one
              allow(checker.send(:strategy).boot_disk).to receive(:mbr_gap).and_return(256.KiB)
            end

            context "in a partitions-based setup" do
              let(:scenario) { "dos_btrfs" }

              include_examples "no errors"
            end

            context "in a LVM-based setup" do
              # examples define own gap
              let(:scenario) { "dos_lvm" }

              context "if the MBR gap has additional space for grubenv" do
                before do
                  allow(checker.send(:strategy).boot_disk).to receive(:mbr_gap).and_return(260.KiB)
                end

                include_examples "no errors"
              end

              context "if the MBR gap has no additional space" do
                before do
                  allow(checker.send(:strategy).boot_disk).to receive(:mbr_gap).and_return(256.KiB)
                end

                context "if there is no separate /boot" do
                  include_examples "missing boot partition"
                end

                context "if there is separate /boot" do
                  let(:scenario) { "dos_lvm_boot_partition" }

                  include_examples "no errors"
                end
              end
            end

            xcontext "in a Software RAID setup" do
            end

            context "in an encrypted setup" do
              let(:scenario) { "dos_encrypted" }

              context "if the MBR gap has additional space for grubenv" do
                before do
                  allow(checker.send(:strategy).boot_disk).to receive(:mbr_gap).and_return(260.KiB)
                end

                include_examples "no errors"
              end

              context "if the MBR gap has no additional space" do
                before do
                  allow(checker.send(:strategy).boot_disk).to receive(:mbr_gap).and_return(256.KiB)
                end

                context "if there is no separate /boot" do
                  include_examples "missing boot partition"
                end

                context "if there is separate /boot" do
                  let(:scenario) { "dos_encrypted_boot_partition" }

                  include_examples "no errors"
                end
              end

            end
          end
        end
      end
    end

    context "in an aarch64 system" do
      let(:architecture) { :aarch64 }
      # it's always UEFI
      let(:efiboot) { true }
      include_examples "efi partition"
    end

    context "in a PPC64 system" do
      let(:architecture) { :ppc }
      let(:efiboot) { false }
      let(:power_nv) { false }

      context "when there is no root" do
        let(:scenario) { "false-swaps" }
        include_examples "unknown boot disk"
      end

      context "in a non-PowerNV system (KVM/LPAR)" do
        let(:power_nv) { false }

        context "with a partitions-based proposal" do

          context "there is a PReP partition" do
            let(:scenario) { "prep" }
            include_examples "no errors"
          end

          context "there is too big PReP partition" do
            let(:scenario) { "prep_big" }

            it "contains a warning for too big PReP partition" do
              expect(checker.warnings.size).to eq(1)
              expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

              message = checker.warnings.first.message
              expect(message).to match(/partition is too big/)
            end
          end

          context "PReP partition missing" do
            let(:scenario) { "trivial" }
            include_examples "missing prep partition"
          end
        end

        context "with a LVM-based proposal" do
          context "there is a PReP partition" do
            let(:scenario) { "prep_lvm" }
            include_examples "no errors"
          end

          context "PReP partition missing" do
            let(:scenario) { "trivial_lvm" }
            include_examples "missing prep partition"
          end
        end

        # TODO: sorry, but I won't write it in xml and yaml does not support it
        # scenario generator would be great
        xcontext "with a Software RAID proposal" do
          context "there is a PReP partition" do
            let(:scenario) { "prep_raid" }
            include_examples "no errors"
          end

          context "PReP partition missing" do
            let(:scenario) { "trivial_raid" }
            include_examples "missing prep partition"
          end
        end

        context "with an encrypted proposal" do
          context "there is a PReP partition" do
            let(:scenario) { "prep_encrypted" }
            include_examples "no errors"
          end

          context "PReP partition missing" do
            let(:scenario) { "trivial_encrypted" }
            include_examples "missing prep partition"
          end
        end
      end

      context "in bare metal (PowerNV)" do
        let(:power_nv) { true }

        context "with a partitions-based proposal" do
          let(:scenario) { "trivial" }

          include_examples "no errors"
        end

        context "with a LVM-based proposal" do
          context "and there is no /boot partition in the system" do
            let(:scenario) { "trivial_lvm" }

            include_examples "missing boot partition"
          end

          context "and there is a /boot partition in the system" do
            let(:scenario) { "lvm_with_boot" }

            include_examples "no errors"
          end
        end

        # TODO: support raid in YaML
        xcontext "with a Software RAID proposal" do
          context "and there is no /boot partition in the system" do
            let(:scenario) { "trivial_raid" }

            include_examples "missing boot partition"
          end

          context "and there is a /boot partition in the system" do
            let(:scenario) { "raid_with_boot" }

            include_examples "no errors"
          end
        end

        context "with an encrypted proposal" do
          context "and there is no /boot partition in the system" do
            let(:scenario) { "trivial_encrypted" }

            include_examples "missing boot partition"
          end

          context "and there is a /boot partition in the system" do
            let(:scenario) { "encrypted_with_boot" }

            include_examples "no errors"
          end
        end
      end
    end

    context "in a S/390 system" do
      let(:architecture) { :s390 }
      let(:efiboot) { false }
      let(:scenario) { "several-dasds" }

      def format_dev(name, type, path)
        fs = fake_devicegraph.find_by_name(name).create_filesystem(type)
        fs.mount_path = path
      end

      def format_zipl(name)
        format_dev(name, Y2Storage::Filesystems::Type::EXT4, "/boot/zipl")
      end

      RSpec.shared_examples "zipl needed if missing" do
        context "and there is a /boot/zipl partition" do
          before { format_zipl("/dev/dasdc2") }

          include_examples "no errors"
        end

        context "and there is no /boot/zipl partition" do
          include_examples "missing zipl partition"
        end
      end

      RSpec.shared_examples "zipl not needed" do
        context "and there is a /boot/zipl partition" do
          before { format_zipl("/dev/dasdc2") }

          include_examples "no errors"
        end

        context "and there is no /boot/zipl partition" do
          include_examples "no errors"
        end
      end

      RSpec.shared_examples "zipl separate boot" do
        context "and /boot uses a non-readable filesystem type (e.g. btrfs)" do
          let(:boot_type) { Y2Storage::Filesystems::Type::BTRFS }

          include_examples "zipl needed if missing"
        end

        context "with /boot formatted in a readable filesystem type (XFS or extX)" do
          let(:boot_type) { Y2Storage::Filesystems::Type::XFS }

          include_examples "zipl not needed"
        end
      end

      RSpec.shared_examples "zipl not accessible root" do
        context "and / uses a non-readable filesystem type (e.g. btrfs)" do
          let(:root_type) { Y2Storage::Filesystems::Type::BTRFS }

          include_examples "zipl needed if missing"
        end

        context "and / is formatted in a readable filesystem type (XFS or extX)" do
          let(:root_type) { Y2Storage::Filesystems::Type::EXT4 }

          include_examples "zipl needed if missing"
        end
      end

      context "when there is no root" do
        include_examples "unknown boot disk"
      end

      context "if / is in a plain partition" do
        before { format_dev(root_name, root_type, "/") }

        let(:root_name) { "/dev/dasdc3" }
        let(:root_type) { Y2Storage::Filesystems::Type::EXT4 }

        context "in a (E)CKD DASD disk formatted as LDL" do
          let(:root_name) { "/dev/dasda1" }

          include_examples "unsupported boot disk"
        end

        context "in the implicit partition table of an FBA device" do
          let(:root_name) { "/dev/dasdb1" }

          # Regression test for bug#1070265. It wrongly claimed booting
          # from FBA DASDs was not supported
          it "contains no error about unsupported disk" do
            expect(checker.warnings).to be_empty
            expect(checker.errors).to be_empty
          end
        end

        context "and there is a separate /boot partition" do
          before { format_dev("/dev/dasdc1", boot_type, "/boot") }

          include_examples "zipl separate boot"
        end

        context "if there is no separate /boot partition" do
          context "and / uses a non-readable filesystem type (e.g. btrfs)" do
            let(:root_type) { Y2Storage::Filesystems::Type::BTRFS }

            include_examples "zipl needed if missing"
          end

          context "and / is formatted in a readable filesystem type (XFS or extX)" do
            let(:root_type) { Y2Storage::Filesystems::Type::XFS }

            include_examples "zipl not needed"
          end
        end
      end

      context "and / is in a encrypted partition" do
        before do
          enc = fake_devicegraph.find_by_name(root_name).create_encryption("enc")
          format_dev(enc.name, root_type, "/")
        end

        let(:root_name) { "/dev/dasdc3" }
        let(:root_type) { Y2Storage::Filesystems::Type::EXT4 }

        context "in a (E)CKD DASD disk formatted as LDL" do
          let(:root_name) { "/dev/dasda1" }

          include_examples "unsupported boot disk"
        end

        context "and there is a separate /boot partition" do
          before { format_dev("/dev/dasdc1", boot_type, "/boot") }

          include_examples "zipl separate boot"
        end

        context "if there is no separate /boot partition" do
          include_examples "zipl not accessible root"
        end
      end

      context "and / is in an LVM logical volume" do
        before { format_dev("/dev/vg0/lv1", root_type, "/") }
        let(:root_type) { Y2Storage::Filesystems::Type::EXT4 }

        context "and there is a separate /boot partition" do
          before { format_dev("/dev/dasdc1", boot_type, "/boot") }

          include_examples "zipl separate boot"
        end

        context "if there is no separate /boot partition" do
          include_examples "zipl not accessible root"
        end
      end

      context "and / is in an MD RAID" do
        before do
          md = Y2Storage::Md.create(fake_devicegraph, "/dev/md0")
          md.md_level = Y2Storage::MdLevel::RAID0
          md.add_device(fake_devicegraph.find_by_name("/dev/dasdc3"))
          md.add_device(fake_devicegraph.find_by_name("/dev/dasdd2"))
          format_dev(md.name, root_type, "/")
        end

        let(:root_type) { Y2Storage::Filesystems::Type::EXT4 }

        context "and there is a separate /boot partition" do
          before { format_dev("/dev/dasdc1", boot_type, "/boot") }

          include_examples "zipl separate boot"
        end

        context "if there is no separate /boot partition" do
          include_examples "zipl not accessible root"
        end
      end
    end

    context "using NFS for the root filesystem" do
      before do
        fs = Y2Storage::Filesystems::Nfs.create(fake_devicegraph, "server", "/path")
        fs.create_mount_point("/")
      end

      context "in a diskless system" do
        let(:scenario) { "nfs1.xml" }

        # Regression test for bug#1090752
        it "does not crash" do
          expect { checker.warnings }.to_not raise_error
          expect { checker.errors }.to_not raise_error
        end

        it "returns no warnings or errors" do
          expect(checker.warnings).to be_empty
          expect(checker.errors).to be_empty
        end
      end

      context "in a system with local disks" do
        let(:scenario) { "empty_hard_disk_50GiB" }

        # This used to consider the local disk as the one to boot from, so it
        # reported wrong errors assuming "/" was going to be there.
        it "returns no warnings or errors" do
          expect(checker.warnings).to be_empty
          expect(checker.errors).to be_empty
        end
      end
    end
  end
end
