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
    fake_scenario("lvm-disk-as-pv.xml")

    allow(Yast::Mode).to receive(:auto).and_return(true)
  end

  subject(:proposal) do
    described_class.new(
      partitioning:, devicegraph: fake_devicegraph, issues_list:
    )
  end

  let(:issues_list) { Installation::AutoinstIssues::List.new }

  let(:partitioning) do
    [
      {
        "device"     => "/dev/system",
        "initialize" => false,
        "type"       => :CT_LVM,
        "partitions" => [
          {
            "lv_name" => "root", "mount" => "/", "filesystem" => :ext4,
            "create" => true, "size" => 90.GiB
          },
          {
            "lv_name" => "swap", "mount" => "swap", "filesystem" => :swap,
            "create" => true, "size" => 2.GiB
          }
        ]
      },
      {
        "device"     => "/dev/sda",
        "initialize" => false,
        "type"       => :CT_DISK,
        "use"        => "all",
        "disklabel"  => "none",
        "partitions" => [
          { "create" => false, "lvm_group" => "system" }
        ]
      }
    ]
  end

  describe "#propose" do
    # Regression test for bsc#1115749
    it "does not allow deleted LVM volume groups affect the name of new VGs" do
      proposal.propose
      vgs = proposal.devices.lvm_vgs

      expect(vgs.size).to eq 1
      # With bsc#1115749, the new (and only) volume group used to be called
      # "system0" because there was a previous "system" VG... that was deleted,
      # so it should not affect the name of the new one.
      expect(vgs.first.vg_name).to eq "system"
    end
  end
end
