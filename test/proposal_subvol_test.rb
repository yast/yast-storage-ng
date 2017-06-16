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
require_relative "support/proposal_context"

describe Y2Storage::GuidedProposal do
  include_context "proposal"

  subject { described_class.new(settings: settings) }

  let(:test_with_subvolumes) { true }

  describe "#propose" do
    let(:scenario) { "empty_hard_disk_50GiB" }

    def root_filesystem
      subject.devices.filesystems.detect { |f| f.mount_point == "/" }
    end

    context "when root filesystem is BtrFS" do
      before do
        settings.root_filesystem_type = Y2Storage::Filesystems::Type::BTRFS
      end

      let(:subvolumes) { root_filesystem.btrfs_subvolumes }
      let(:x86_subvolumes) { ["@/boot/grub2/i386-pc", "@/boot/grub2/x86_64-efi"] }
      let(:s390_subvolumes) { ["@/boot/grub2/s390x-emu"] }

      it "proposes the top level subvolume" do
        subject.propose
        top_level_subvolume = subvolumes.detect { |s| s.id == 5 }

        expect(top_level_subvolume).not_to be_nil
        expect(top_level_subvolume.path).to eq("")
      end

      context "and there is not a default subvolume" do
        before { settings.btrfs_default_subvolume = nil }

        it "proposes top level subvolume as default subvolume" do
          subject.propose
          default_subvol = subvolumes.detect(&:default_btrfs_subvolume?)

          expect(default_subvol).to eq(root_filesystem.top_level_btrfs_subvolume)
        end
      end

      context "and there is a default subvolume" do
        it "proposes as default the correct subvolume" do
          settings.btrfs_default_subvolume = "@@@"

          subject.propose
          default_subvol = subvolumes.detect(&:default_btrfs_subvolume?)

          expect(default_subvol).not_to be_nil
          expect(default_subvol.path).to eq("@@@")
        end
      end

      context "and there are planned subvolumes" do
        before do
          settings.subvolumes = [
            Y2Storage::SubvolSpecification.new("myhome", copy_on_write: true),
            Y2Storage::SubvolSpecification.new("myopt", copy_on_write: false)
          ]
        end

        it "proposes planned subvolumes" do
          subject.propose
          expect(subvolumes.map(&:path)).to include("@/myhome", "@/myopt")
          expect(subvolumes.detect { |s| s.path == "@/myhome" }.nocow?).to be(false)
          expect(subvolumes.detect { |s| s.path == "@/myopt" }.nocow?).to be(true)
        end

        it "does not propose not planned subvolumes" do
          subject.propose
          expect(subvolumes.map(&:path)).not_to include("@/opt")
        end
      end

      context "and there are not planned subvolumes" do
        it "proposes correct COW subvolumes" do
          expected_cow_subvolumes = [
            "@/home",
            "@/opt",
            "@/srv",
            "@/tmp",
            "@/usr/local",
            "@/var/cache",
            "@/var/crash",
            "@/var/lib/machines",
            "@/var/lib/mailman",
            "@/var/lib/named",
            "@/var/log",
            "@/var/opt",
            "@/var/spool",
            "@/var/tmp"
          ]

          subject.propose
          cow_subvolumes = subvolumes.reject { |s| s.nocow? }

          expect(cow_subvolumes.map(&:path)).to include(*expected_cow_subvolumes)
        end

        it "proposes correct NoCOW subvolumes" do
          expected_nocow_subvolumes = [
            "@/var/lib/libvirt/images",
            "@/var/lib/mariadb",
            "@/var/lib/mysql",
            "@/var/lib/pgsql"
          ]

          subject.propose
          nocow_subvolumes = subvolumes.select { |s| s.nocow? }

          expect(nocow_subvolumes.map(&:path)).to contain_exactly(*expected_nocow_subvolumes)
        end
      end

      context "when there is seperate home" do
        let(:separate_home) { true }

        it "does not propose a subvolume for home" do
          subject.propose
          expect(subvolumes.detect { |s| s.path == "@/home" }).to be_nil
        end
      end

      context "when architecture is x86" do
        let(:architecture) { :x86 }

        it "proposes correct x86 specific subvolumes" do
          subject.propose
          expect(subvolumes.map(&:path)).to include(*x86_subvolumes)
        end

        it "does not propose other arch subvolumes" do
          subject.propose
          expect(subvolumes.map(&:path)).not_to include(*s390_subvolumes)
        end
      end

      context "when architecture is s390" do
        let(:architecture) { :s390 }

        it "proposes correct s390 specific subvolumes" do
          subject.propose
          expect(subvolumes.map(&:path)).to include(*s390_subvolumes)
        end

        it "does not propose other arch subvolumes" do
          subject.propose
          expect(subvolumes.map(&:path)).not_to include(*x86_subvolumes)
        end
      end
    end
  end
end
