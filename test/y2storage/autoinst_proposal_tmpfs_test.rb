#!/usr/bin/env rspec

# Copyright (c) [2020] SUSE LLC
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

  subject(:proposal) do
    described_class.new(
      partitioning:, devicegraph: fake_devicegraph, issues_list:
    )
  end

  let(:issues_list) { Installation::AutoinstIssues::List.new }

  describe "#propose" do
    before { fake_scenario(scenario) }

    let(:scenario) { "empty_hard_disk_50GiB" }

    let(:vda) do
      {
        "device"     => "/dev/sda",
        "type"       => :CT_DISK,
        "use"        => "all",
        "partitions" => [
          { "create" => true, "format" => true, "mount" => "/", "size" => "max" },
          { "create" => true, "format" => true, "mount" => "swap", "size" => "1GiB" }
        ]
      }
    end

    let(:tmpfs0) do
      {
        "type"       => :CT_TMPFS,
        "partitions" => [
          { "mount" => "/srv", "fstopt" => "size=512M" },
          { "mount" => "/var/tmp", "fstopt" => "size=3GB" }
        ]
      }
    end

    let(:tmpfs1) do
      {
        "type"       => :CT_TMPFS,
        "partitions" => [
          { "mount" => "/mnt/tmp", "fstopt" => "size=256M" }
        ]
      }
    end

    let(:partitioning) { [vda, tmpfs0, tmpfs1] }

    it "adds one tmp filesystem for each partition section" do
      proposal.propose
      tmpfs = proposal.devices.tmp_filesystems
      expect(tmpfs).to contain_exactly(
        an_object_having_attributes(mount_path: "/srv", mount_options: ["size=512M"]),
        an_object_having_attributes(mount_path: "/var/tmp", mount_options: ["size=3GB"]),
        an_object_having_attributes(mount_path: "/mnt/tmp", mount_options: ["size=256M"])
      )
    end

    it "does not register any issue" do
      proposal.propose
      expect(issues_list).to be_empty
    end

    context "when a mount point is missing" do
      let(:tmpfs1) do
        {
          "type"       => :CT_TMPFS,
          "partitions" => [
            { "fstopt" => "size=256M" }
          ]
        }
      end

      it "registers an issue" do
        proposal.propose
        issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::MissingValue) }
        expect(issue).to_not be_nil
        expect(issue.attr).to eq(:mount)
      end
    end
  end
end
