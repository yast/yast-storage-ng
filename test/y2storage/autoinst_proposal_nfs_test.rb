#!/usr/bin/env rspec

#
# Copyright (c) [2019] SUSE LLC
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
  using Y2Storage::Refinements::SizeCasts

  before do
    fake_scenario(scenario)

    allow(Yast::Mode).to receive(:auto).and_return(true)
  end

  let(:scenario) { "empty_hard_disk_15GiB" }

  subject(:proposal) do
    described_class.new(
      partitioning: partitioning, devicegraph: fake_devicegraph, issues_list: issues_list
    )
  end

  let(:issues_list) { Y2Storage::AutoinstIssues::List.new }

  describe "#propose" do
    shared_examples "NFS proposal" do
      let(:disk_drive) do
        {
          "device" => "/dev/sda",
          "type" => :CT_DISK, "use" => "all", "initialize" => true, "disklabel" => "msdos",
          "partitions" => [
            {
              "create" => true, "filesystem" => :swap, "format" => true, "mount" => "swap",
              "size" => 2.GiB
            }
          ]
        }
      end

      let(:partitioning) { [nfs_drive, disk_drive] }

      it "creates a NFS filesystem for installing over it" do
        proposal.propose
        nfs = proposal.devices.nfs_mounts.first

        expect(nfs).to_not be_nil
        expect(nfs.mount_path).to eq("/")
      end

      it "creates local partitions when required" do
        proposal.propose
        sda1 = proposal.devices.find_by_name("/dev/sda1")

        expect(sda1.swap?).to eq(true)
        expect(sda1.size).to eq(2.GiB)
      end

      it "does not register any issue" do
        proposal.propose
        expect(issues_list).to be_empty
      end

    end

    context "when installing over NFS" do
      context "and the old NFS drive format is used" do
        let(:nfs_drive) do
          {
            "device"     => "/dev/nfs",
            "partitions" => [
              {
                "device" => "192.168.56.1:/root_fs",
                "mount"  => "/"
              }
            ]
          }
        end

        include_examples "NFS proposal"
      end

      context "and the new NFS drive format is used" do
        let(:nfs_drive) do
          {
            "device"     => "192.168.56.1:/root_fs",
            "type"       => :CT_NFS,
            "partitions" => [
              {
                "mount" => "/"
              }
            ]
          }
        end

        include_examples "NFS proposal"
      end
    end
  end
end
