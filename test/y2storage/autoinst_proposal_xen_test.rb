#!/usr/bin/env rspec

#
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

describe Y2Storage::AutoinstProposal do
  subject(:proposal) do
    described_class.new(
      partitioning: partitioning, devicegraph: fake_devicegraph, issues_list: issues_list
    )
  end

  let(:issues_list) { Y2Storage::AutoinstIssues::List.new }

  before do
    allow(Yast::Mode).to receive(:auto).and_return(true)
  end

  describe "#propose" do
    before { fake_scenario(scenario) }

    RSpec.shared_examples "AutoYaST only Xen partitions" do
      it "does not register any issue" do
        proposal.propose
        expect(issues_list).to be_empty
      end

      it "correctly formats all the virtual partitions" do
        proposal.propose

        xvda1 = proposal.devices.find_by_name("/dev/xvda1")
        expect(xvda1.filesystem).to have_attributes(
          type:       Y2Storage::Filesystems::Type::BTRFS,
          mount_path: "/"
        )
        xvda2 = proposal.devices.find_by_name("/dev/xvda2")
        expect(xvda2.filesystem).to have_attributes(
          type:       Y2Storage::Filesystems::Type::SWAP,
          mount_path: "swap"
        )
      end
    end

    RSpec.shared_examples "AutoYaST Xen partitions and disk" do
      it "correctly formats all the virtual and real partitions" do
        proposal.propose

        xvda1 = proposal.devices.find_by_name("/dev/xvda1")
        expect(xvda1.filesystem).to have_attributes(
          type:       Y2Storage::Filesystems::Type::BTRFS,
          mount_path: "/"
        )
        xvda2 = proposal.devices.find_by_name("/dev/xvda2")
        expect(xvda2.filesystem).to have_attributes(
          type:       Y2Storage::Filesystems::Type::SWAP,
          mount_path: "swap"
        )

        # NOTE: /dev/xvdc1 is not the only /dev/xvdc partition in the final
        # system. AutoYaST also creates a bios_boot partition because it
        # always adds partitions needed for booting. In a Xen environment
        # with Xen virtual partitions that behavior is probably undesired
        # (let's wait for feedback about it).
        xvdc = proposal.devices.find_by_name("/dev/xvdc")
        expect(xvdc.partitions).to include(
          an_object_having_attributes(
            filesystem_type:       Y2Storage::Filesystems::Type::XFS,
            filesystem_mountpoint: "/home"
          )
        )
      end
    end

    describe "using the legacy format for Xen virtual partitions" do
      let(:xvda1_sect) do
        {
          "partition_nr" => 1, "create" => false,
          "filesystem" => "btrfs", "format" => true, "mount" => "/"
        }
      end

      let(:xvda2_sect) do
        {
          "partition_nr" => 2, "create" => false, "mount_by" => "device",
          "filesystem" => "swap", "format" => true, "mount" => "swap"
        }
      end

      let(:xvdc1_sect) do
        { "filesystem" => :xfs, "mount" => "/home", "size" => "max", "create" => true }
      end

      # Mock the system lookup performed as last resort to find a device
      before { allow(Y2Storage::BlkDevice).to receive(:find_by_any_name) }

      context "and no other kind of devices" do
        let(:scenario) { "xen-partitions.xml" }

        let(:partitioning) do
          [{ "device" => "/dev/xvda", "use" => "all", "partitions" => [xvda1_sect, xvda2_sect] }]
        end

        include_examples "AutoYaST only Xen partitions"
      end

      context "and Xen hard disks" do
        let(:scenario) { "xen-disks-and-partitions.xml" }

        let(:partitioning) do
          [
            { "device" => "/dev/xvda", "use" => "all", "partitions" => [xvda1_sect, xvda2_sect] },
            { "device" => "/dev/xvdc", "use" => "all", "partitions" => [xvdc1_sect] }
          ]
        end

        include_examples "AutoYaST Xen partitions and disk"
      end
    end

    describe "using the normal format for Xen virtual partitions (as disks)" do
      let(:xvda1_sect) do
        {
          "device" => "/dev/xvda1", "disklabel" => "none",
          "partitions" => [
            { "partition_nr" => 1, "filesystem" => "btrfs", "format" => true, "mount" => "/" }
          ]
        }
      end

      let(:xvda2_sect) do
        {
          "device" => "/dev/xvda2", "disklabel" => "none",
          "partitions" => [
            {
              "partition_nr" => 1, "filesystem" => "swap", "format" => true,
              "mount" => "swap", "mount_by" => "device"
            }
          ]
        }
      end

      let(:xvdc1_sect) do
        { "filesystem" => :xfs, "mount" => "/home", "size" => "max", "create" => true }
      end

      context "and no other kind of devices" do
        let(:scenario) { "xen-partitions.xml" }
        let(:partitioning) { [xvda1_sect, xvda2_sect] }

        include_examples "AutoYaST only Xen partitions"
      end

      context "and Xen hard disks" do
        let(:scenario) { "xen-disks-and-partitions.xml" }

        let(:partitioning) do
          [
            xvda1_sect, xvda2_sect,
            { "device" => "/dev/xvdc", "use" => "all", "partitions" => [xvdc1_sect] }
          ]
        end

        include_examples "AutoYaST Xen partitions and disk"
      end
    end

    RSpec.shared_examples "use first partition subsection" do
      it "formats the virtual partition using the information from the first <partition> section" do
        proposal.propose

        xvda1 = proposal.devices.find_by_name("/dev/xvda1")
        expect(xvda1.filesystem).to have_attributes(
          type:       Y2Storage::Filesystems::Type::BTRFS,
          mount_path: "/"
        )
      end

      it "registers an AutoinstIssues::SurplusPartitions warning" do
        proposal.propose
        expect(issues_list).to_not be_empty
        issue = issues_list.first
        expect(issue.class).to eq Y2Storage::AutoinstIssues::SurplusPartitions
      end
    end

    RSpec.shared_examples "no partitionable error" do
      it "registers an AutoinstIssues::NoPartitionable error" do
        proposal.propose
        expect(issues_list).to_not be_empty
        issue = issues_list.first
        expect(issue.class).to eq Y2Storage::AutoinstIssues::NoPartitionable
      end
    end

    describe "when a given Xen virtual partition is requested to contain partitions" do
      let(:scenario) { "xen-partitions.xml" }

      let(:partitioning) do
        [
          {
            "device" => "/dev/xvda1", "disklabel" => disklabel, "use" => "all",
            "partitions" => [
              { "create" => true, "filesystem" => "btrfs", "format" => true, "mount" => "/" },
              { "create" => true, "filesystem" => "swap", "format" => true, "mount" => "swap" }
            ]
          }
        ]
      end

      context "with disklabel set to some partition table type" do
        let(:disklabel) { "gpt" }

        include_examples "no partitionable error"
      end

      context "with disklabel set to 'none'" do
        let(:disklabel) { "none" }

        include_examples "use first partition subsection"
      end

      context "with no disklabel attribute" do
        let(:disklabel) { nil }

        include_examples "use first partition subsection"
      end
    end

    describe "when a drive with several partitions matches order with a Xen virtual partition" do
      let(:partitioning) do
        [
          {
            "disklabel" => disklabel, "use" => "all",
            "partitions" => [
              { "create" => true, "filesystem" => "btrfs", "format" => true, "mount" => "/" },
              { "create" => true, "filesystem" => "swap", "format" => true, "mount" => "swap" }
            ]
          }
        ]
      end

      context "if there is another device that supports partitions" do
        let(:scenario) { "xen-disks-and-partitions.xml" }

        context "with disklabel set to some partition table type" do
          let(:disklabel) { "gpt" }

          # The virtual partition could be skipped and the drive section could
          # then be applied to the hard disk (xvdc), but AutoYaST is not expected
          # to take such kind of decisions based on the properties of the devices.
          # It just matches by the device name and the <drive> position in the
          # profile.
          include_examples "no partitionable error"
        end

        context "with disklabel set to 'none'" do
          let(:disklabel) { "none" }

          include_examples "use first partition subsection"
        end

        context "with no disklabel attribute" do
          let(:disklabel) { nil }

          include_examples "use first partition subsection"
        end
      end

      context "if there is no alternative to accomodate the drive" do
        let(:scenario) { "xen-partitions.xml" }

        context "with disklabel set to some partition table type" do
          let(:disklabel) { "gpt" }

          include_examples "no partitionable error"
        end

        context "with disklabel set to 'none'" do
          let(:disklabel) { "none" }

          include_examples "use first partition subsection"
        end

        context "with no disklabel attribute" do
          let(:disklabel) { nil }

          include_examples "use first partition subsection"
        end
      end
    end
  end
end
