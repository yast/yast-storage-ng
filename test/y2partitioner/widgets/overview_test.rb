#!/usr/bin/env rspec

# Copyright (c) [2017-2020] SUSE LLC
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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/overview"

describe Y2Partitioner::Widgets::OverviewTreePager do
  before do
    devicegraph_stub(scenario)
    Yast::ProductFeatures.Import(control_file_content)

    allow(Yast2::Popup).to receive(:show).and_return(:yes)
  end

  let(:control_file_content) do
    file_path = File.join(DATA_PATH, "control_files", control_file)
    Yast::XML.XMLToYCPFile(file_path)
  end

  subject { described_class.new("hostname") }

  let(:scenario) { "lvm-two-vgs.yml" }

  let(:control_file) { "caasp.xml" }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  include_examples "CWM::Pager"

  describe "#init" do
    it "asks to UIState for a statuses cleaning" do
      expect(Y2Partitioner::UIState.instance).to receive(:prune)

      subject.init
    end

    it "notifies the current page to UIState" do
      expect(Y2Partitioner::UIState.instance).to receive(:select_page)

      subject.init
    end
  end

  describe "#device_page" do
    let(:vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0") }

    context "when there is a page associated to the requested device" do
      let(:device) { vg }

      it "returns the page" do
        page = subject.device_page(device)
        expect(page).to be_a(CWM::Page)
        expect(page.device).to eq(device)
      end
    end

    context "when there is not a page associated to the requested device" do
      let(:device) { current_graph.find_by_name("/dev/sda1") }

      it "returns nil" do
        page = subject.device_page(device)
        expect(page).to be_nil
      end
    end

    context "when the device is NFS" do
      let(:scenario) { "nfs1.xml" }
      let(:device) { current_graph.nfs_mounts.first }

      it "returns the general NFS page" do
        page = subject.device_page(device)
        expect(page).to be_a(CWM::Page)
        expect(page).to be_a(Y2Partitioner::Widgets::Pages::NfsMounts)
      end
    end
  end

  shared_context "pages" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    let(:overview_tree) { widgets.find { |w| w.is_a?(Y2Partitioner::Widgets::OverviewTree) } }

    let(:system_pager) do
      overview_tree.items.find { |i| i.page.is_a?(Y2Partitioner::Widgets::Pages::System) }
    end

    let(:disks_pager) do
      overview_tree.items.find { |i| i.page.is_a?(Y2Partitioner::Widgets::Pages::Disks) }
    end

    let(:md_pager) do
      overview_tree.items.find { |i| i.page.is_a?(Y2Partitioner::Widgets::Pages::MdRaids) }
    end

    let(:lvm_pager) do
      overview_tree.items.find { |i| i.page.is_a?(Y2Partitioner::Widgets::Pages::Lvm) }
    end

    let(:bcache_pager) do
      overview_tree.items.find { |i| i.page.is_a?(Y2Partitioner::Widgets::Pages::Bcaches) }
    end

    let(:btrfs_pager) do
      overview_tree.items.find { |i| i.page.is_a?(Y2Partitioner::Widgets::Pages::BtrfsFilesystems) }
    end

    let(:tmpfs_pager) do
      overview_tree.items.find { |i| i.page.is_a?(Y2Partitioner::Widgets::Pages::TmpfsFilesystems) }
    end

    let(:pages) { pager.pages - [pager.page] }

    let(:pages_devices) { pages.map { |p| p.device.name } }

    let(:pager) { system_pager }
  end

  describe "#contents" do
    let(:scenario) { "empty-dasd-and-multipath.xml" }

    include_context "pages"

    it "has a OverviewTree widget" do
      expect(overview_tree).to_not be_nil
    end

    it "has a section for all the devices" do
      expect(system_pager).to_not be_nil
    end

    it "has a section for the disk devices" do
      expect(disks_pager).to_not be_nil
    end

    it "has a section for the Software Raids" do
      expect(md_pager).to_not be_nil
    end

    it "has a section for the LVM volume groups" do
      expect(lvm_pager).to_not be_nil
    end

    it "has a section for the Bcache devices" do
      expect(bcache_pager).to_not be_nil
    end

    it "has a section for the Btrfs filesystems" do
      expect(btrfs_pager).to_not be_nil
    end

    it "has a section for the Tmpfs filesystems" do
      expect(tmpfs_pager).to_not be_nil
    end

    context "when there are disk, dasd or multipath devices" do
      let(:scenario) { "empty-dasd-and-multipath.xml" }

      let(:pager) { disks_pager }

      it "disks pager has a page for each dasd device" do
        expect(pages_devices).to include("/dev/dasdb")
      end

      it "disks pager has a page for each multipath device" do
        multipaths = [
          "/dev/mapper/36005076305ffc73a00000000000013b4",
          "/dev/mapper/36005076305ffc73a00000000000013b5"
        ]

        expect(pages_devices).to include(*multipaths)
      end

      it "disks pager has a page for each disk device" do
        expect(pages_devices).to include("/dev/sde")
      end

      it "disks pager does not have a page for disks belonging to a multipath" do
        expect(pages_devices).to_not include("/dev/sda")
      end
    end

    context "when there Xen devices representing disks and virtual partitions" do
      let(:scenario) { "xen-disks-and-partitions.xml" }

      let(:pager) { disks_pager }

      it "disks pager has a page for each Xen disk" do
        expect(pages_devices).to include("/dev/xvdc")
      end

      it "disks pager has a page for each Xen virtual partition" do
        expect(pages_devices).to include("/dev/xvda1", "/dev/xvda2")
      end

      it "disks pager does not include an extra device to group Xen virtual partitions" do
        expect(pages_devices).to_not include("/dev/xvda")
      end
    end

    context "when there are BIOS RAIDs" do
      let(:scenario) { "md-imsm1-devicegraph.xml" }

      let(:mda) { "/dev/md/a" }

      let(:mdb) { "/dev/md/b" }

      let(:sda) { "/dev/sda" }

      let(:pager) { disks_pager }

      it "disks section has an entry for each BIOS RAID device" do
        expect(pages_devices).to include("/dev/md/a", "/dev/md/b")
      end

      it "disks section has an entry for each disk device" do
        expect(pages_devices).to include("/dev/sda")
      end

      it "disks section has no entry for disks belonging to a BIOS RAID" do
        expect(pages_devices).to_not include("/dev/sdb", "/dev/sdc", "/dev/sdd")
      end
    end

    context "when there are LVM volume groups" do
      let(:scenario) { "lvm-two-vgs.yml" }

      let(:pager) { lvm_pager }

      it "LVM section has an entry for each volume group" do
        expect(pages_devices).to contain_exactly("/dev/vg0", "/dev/vg1")
      end
    end

    context "when there are Software RAIDs" do
      let(:scenario) { "md_raid" }

      let(:pager) { md_pager }

      it "Software Raids section has an entry for each Software RAID" do
        expect(pages_devices).to contain_exactly("/dev/md/md0")
      end
    end

    context "when there are Bcache devices" do
      let(:scenario) { "bcache1.xml" }

      let(:pager) { bcache_pager }

      it "Bcache section has an entry for each Bcache device" do
        expect(pages_devices).to contain_exactly("/dev/bcache0", "/dev/bcache1", "/dev/bcache2")
      end
    end

    context "when there are BTRFS filesystems" do
      let(:scenario) { "mixed_disks_btrfs" }

      let(:pager) { btrfs_pager }

      it "Btrfs section has an entry for each Btrfs filesystem" do
        filesystems = [
          "Btrfs sda2",
          "Btrfs sdb2",
          "Btrfs sdb3",
          "Btrfs sdd1",
          "Btrfs sde1"
        ]

        expect(pages_devices).to contain_exactly(*filesystems)
      end
    end

    context "when there are Tmpfs filesystems" do
      let(:scenario) { "tmpfs1-devicegraph.xml" }

      let(:pager) { tmpfs_pager }

      it "Tmpfs section has an entry for each Tmpfs filesystem" do
        expect(pages_devices).to contain_exactly("Tmpfs /test1", "Tmpfs /test2", "Tmpfs /test5")
      end
    end
  end

  describe "#validate" do
    before do
      allow(Y2Storage::SetupChecker).to receive(:new).and_return(checker)
      allow(checker).to receive(:valid?).and_return(valid_setup)
      allow(checker).to receive(:errors).and_return(fatal_errors)

      allow(Y2Partitioner::SetupErrorsPresenter).to receive(:new).and_return(presenter)
      allow(presenter).to receive(:to_html).and_return("html representation")

      allow(Yast2::Popup).to receive(:show).and_return(user_input)
      allow(Y2Storage::StorageFeaturesList).to receive(:from_bitfield).and_return(used_features)
      allow(used_features).to receive(:pkg_list).and_return(["xfsprogs"])
      allow(Yast::Package).to receive(:Installed).and_return false
      allow(Yast::PackageSystem).to receive(:CheckAndInstallPackages)
        .and_return(installed_packages)
      allow(Yast::Mode).to receive(:installation).and_return(installation)
    end

    let(:checker) { instance_double(Y2Storage::SetupChecker) }

    let(:presenter) { instance_double(Y2Partitioner::SetupErrorsPresenter) }

    let(:valid_setup) { nil }

    let(:user_input) { nil }

    let(:fatal_errors) { [] }

    let(:used_features) { Y2Storage::StorageFeaturesList.new }

    let(:installed_packages) { true }

    let(:installation) { false }

    context "when the current setup is not valid" do
      context "and when errors are fatal" do
        let(:valid_setup) { false }
        let(:fatal_errors) { [double] }

        it "shows an error popup" do
          expect(Yast2::Popup).to receive(:show)
          subject.validate
        end

        it "prevents continuing" do
          expect(Yast2::Popup).to receive(:show)
          expect(subject.validate).to eq(false)
        end

        it "does not check for missing packages" do
          expect(Yast::PackageSystem).to_not receive(:CheckAndInstallPackages)
          subject.validate
        end
      end

      context "and errors are no fatal" do
        let(:valid_setup) { false }

        it "shows an error popup" do
          expect(Yast2::Popup).to receive(:show)
          subject.validate
        end

        context "and the user accepts to continue" do
          let(:user_input) { :yes }

          it "returns true" do
            expect(subject.validate).to eq(true)
          end

          it "checks for needed packages" do
            expect(Yast::PackageSystem).to receive(:CheckAndInstallPackages)
              .with(["xfsprogs"])
            subject.validate
          end

          context "but the user refuses to install them " do
            let(:installed_packages) { false }

            it "returns false" do
              expect(subject.validate).to eq(false)
            end
          end

          context "but running on installation" do
            let(:installation) { true }

            it "does not check for missing packages" do
              expect(Yast::PackageSystem).to_not receive(:CheckAndInstallPackages)
              subject.validate
            end
          end
        end

        context "and the user declines to continue" do
          let(:user_input) { :no }

          it "returns false" do
            expect(subject.validate).to eq(false)
          end

          it "does not check for missing packages" do
            expect(Yast::PackageSystem).to_not receive(:CheckAndInstallPackages)
            subject.validate
          end
        end
      end
    end

    context "when the current setup is valid" do
      let(:valid_setup) { true }

      it "does not show an error popup" do
        expect(Yast2::Popup).to_not receive(:show)
        subject.validate
      end

      it "returns true" do
        expect(subject.validate).to eq(true)
      end

      it "checks for needed packages" do
        expect(Yast::PackageSystem).to receive(:CheckAndInstallPackages)
          .with(["xfsprogs"])
        subject.validate
      end

      context "but the user refuses to install them " do
        let(:installed_packages) { false }

        it "returns false" do
          expect(subject.validate).to eq(false)
        end
      end

      context "but running on installation" do
        let(:installation) { true }

        it "does not check for missing packages" do
          expect(Yast::PackageSystem).to_not receive(:CheckAndInstallPackages)
          subject.validate
        end
      end
    end
  end

  describe "#open_items" do
    before do
      allow(Yast::UI).to receive(:QueryWidget).with(anything, :OpenItems)
        .and_return(ui_open_items)
    end

    let(:scenario) { "lvm-two-vgs.yml" }

    let(:with_children) do
      [
        "Y2Partitioner::Widgets::Pages::Disks",
        "Y2Partitioner::Widgets::Pages::Lvm"
      ]
    end

    let(:ui_open_items) do
      { "Y2Partitioner::Widgets::Pages::Lvm" => "ID", "disk:/dev/sda" => "ID" }
    end

    it "contains an entry for each item with children" do
      expect(subject.open_items.keys).to contain_exactly(*with_children)
    end

    it "sets the value of open items to true" do
      expect(subject.open_items["Y2Partitioner::Widgets::Pages::Lvm"]).to eq true
    end
  end

  describe "#device_page?" do
    include_context "pages"

    before do
      allow(subject).to receive(:current_page).and_return(page)
    end

    let(:pager) { disks_pager }

    context "when the current page has an associated device" do
      let(:page) { pages.first }

      it "returns true" do
        expect(subject.device_page?).to eq(true)
      end
    end

    context "when the current page has no associated device" do
      let(:page) { pager.page }

      it "returns false" do
        expect(subject.device_page?).to eq(false)
      end
    end
  end
end
