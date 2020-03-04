#!/usr/bin/env rspec
#
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
require "y2storage/package_handler"

describe Y2Storage::PackageHandler do
  context("without adding any devicegraph's storage features") do
    subject { described_class.new }

    it "has an empty package list" do
      expect(subject.pkg_list).to be_empty
    end
  end

  context("using a devicegraph with Btrfs and LVM") do
    let(:dg_features) { ::Storage::UF_BTRFS | ::Storage::UF_LVM }
    let(:devicegraph) { instance_double("::Storage::Devicegraph", used_features: dg_features) }
    let(:feature_pkg) { ["lvm2", "btrfsprogs", "e2fsprogs"] }
    before do
      allow(Yast::Package).to receive(:Installed).and_return(false)
      allow(Yast::Package).to receive(:Installed).with("util-linux").and_return(true)
      allow(Yast::Pkg).to receive(:PkgSolve).and_return(true)
    end
    subject do
      pkg_handler = described_class.new
      pkg_handler.add_feature_packages(devicegraph)
      pkg_handler
    end

    it "adds the packages for the storage features used in the devicegraph" do
      expect(subject.pkg_list).to contain_exactly("btrfsprogs", "e2fsprogs", "lvm2")
    end

    it "removes duplicate packages" do
      subject.add_packages(["lvm2", "btrfsprogs"])
      expect(subject.pkg_list).to contain_exactly("btrfsprogs", "e2fsprogs", "lvm2")
    end

    it "removes packages that are already installed" do
      subject.add_packages(["util-linux"])
      expect(subject.pkg_list).to contain_exactly("btrfsprogs", "e2fsprogs", "lvm2")
    end

    describe "#commit" do
      before { allow(Yast::Mode).to receive(:installation).and_return(installation) }

      context "during installation" do
        let(:installation) { true }

        it "sets the proposal packages" do
          expect(Yast::PackagesProposal).to receive(:SetResolvables)
          subject.commit
        end

        it "does not try to install the packages" do
          allow(Yast::PackagesProposal).to receive(:SetResolvables)
          expect(Yast::Package).to_not receive(:DoInstall)
          subject.commit
        end

        it "pops up an error dialog if setting the proposal packages failed" do
          allow(Yast::PackagesProposal).to receive(:SetResolvables).and_return(false)
          expect(Yast::Report).to receive(:Error)
          subject.commit
        end

        it "does not check for already installed packages" do
          allow(Yast::PackagesProposal).to receive(:SetResolvables)
          expect(Yast::Package).to_not receive(:Installed)
          subject.commit
        end
      end

      context "in the installed system" do
        let(:installation) { false }
        before { allow(Yast::Package).to receive(:Installed).and_return false }

        it "installs packages directly in the installed system" do
          expect(Yast::Package).to receive(:DoInstall).with(subject.pkg_list)
          subject.commit
        end

        it "does not install packages that are already installed" do
          # Let's simulate the first package is already installed
          allow(Yast::Package).to receive(:Installed).with(feature_pkg[0]).and_return true

          expect(Yast::Package).to receive(:DoInstall).with(feature_pkg[1..-1])
          subject.commit
        end

        it "pops up an error dialog if package installation failed" do
          allow(Yast::Package).to receive(:DoInstall).and_return(false)
          expect(Yast::Report).to receive(:Error)
          subject.commit
        end
      end
    end
  end

  context("using a devicegraph with Ext4 and NTFS") do
    let(:dg_features) { ::Storage::UF_EXT4 | ::Storage::UF_NTFS }
    let(:devicegraph) { instance_double("::Storage::Devicegraph", used_features: dg_features) }
    let(:feature_pkg) { ["e2fsprogs"] }
    before do
      allow(Yast::Package).to receive(:Installed).and_return(false)
      allow(Yast::Package).to receive(:Installed).with("util-linux").and_return(true)
      allow(Yast::Pkg).to receive(:PkgSolve).and_return(true)
    end
    subject do
      pkg_handler = described_class.new
      pkg_handler.add_feature_packages(devicegraph)
      pkg_handler
    end

    it "does not insist on installing optional packages that are not available" do
      allow(Yast::Package).to receive(:Available).with("ntfs-3g").and_return(false)
      allow(Yast::Package).to receive(:Available).with("ntfsprogs").and_return(false)
      expect(subject.pkg_list).to contain_exactly("e2fsprogs")
    end

    it "still installs optional packages when available and needed" do
      allow(Yast::Package).to receive(:Available).with("ntfs-3g").and_return(true)
      allow(Yast::Package).to receive(:Available).with("ntfsprogs").and_return(true)
      expect(subject.pkg_list).to contain_exactly("e2fsprogs", "ntfs-3g", "ntfsprogs")
    end
  end

end
