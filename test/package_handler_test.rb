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
    let(:devicegraph) { instance_double("::Storage::devicegraph", used_features: dg_features) }
    let(:feature_pkg) { ["btrfsprogs", "e2fsprogs", "lvm2"] }
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
      subject.compact
      expect(subject.pkg_list).to contain_exactly("btrfsprogs", "e2fsprogs", "lvm2")
    end

    it "removes packages that are already installed" do
      subject.add_packages(["util-linux"])
      subject.compact
      expect(subject.pkg_list).to contain_exactly("btrfsprogs", "e2fsprogs", "lvm2")
    end

    it "sets the proposal packages during installation" do
      allow(Yast::Mode).to receive(:installation).and_return(true)
      allow(Yast::Package).to receive(:DoInstall).and_return(true)
      allow(Yast::PackagesProposal).to receive(:SetResolvables).and_return(true)
      expect(Yast::PackagesProposal).to receive(:SetResolvables)
      subject.commit
    end

    it "installs packages directly in the installed system" do
      allow(Yast::Mode).to receive(:installation).and_return(false)
      allow(Yast::Package).to receive(:DoInstall).and_return(true)
      expect(Yast::Package).to receive(:DoInstall).with(subject.pkg_list)
      subject.commit
    end

    it "pops up an error dialog if setting the proposal packages failed" do
      allow(Yast::Mode).to receive(:installation).and_return(true)
      allow(Yast::PackagesProposal).to receive(:SetResolvables).and_return(false)
      allow(Yast::Report).to receive(:Error)
      expect(Yast::PackagesProposal).to receive(:SetResolvables)
      expect(Yast::Report).to receive(:Error)
      subject.commit
    end

    it "pops up an error dialog if package installation failed" do
      allow(Yast::Mode).to receive(:installation).and_return(false)
      allow(Yast::Package).to receive(:DoInstall).and_return(false)
      allow(Yast::Report).to receive(:Error)
      expect(Yast::Package).to receive(:DoInstall).with(subject.pkg_list)
      expect(Yast::Report).to receive(:Error)
      subject.commit
    end

  end
end
