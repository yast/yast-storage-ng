#!/usr/bin/env rspec
#
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

require_relative "../spec_helper"
require "y2storage"

describe Y2Storage::Proposal::TmpfsCreator do
  before do
    fake_scenario(scenario)
  end

  subject { described_class.new(fake_devicegraph) }

  describe "#create_filesystem" do
    let(:scenario) { "empty_disks" }

    let(:planned_srv) do
      planned_tmpfs("/srv", fstab_options: ["size=256M"])
    end

    it "creates a new tmpfs filesystem" do
      result = subject.create_tmpfs(planned_srv)
      tmpfs = result.devicegraph.tmp_filesystems.first
      expect(tmpfs.mount_path).to eq(planned_srv.mount_point)
      expect(tmpfs.mount_options).to eq(planned_srv.fstab_options)
    end
  end
end
