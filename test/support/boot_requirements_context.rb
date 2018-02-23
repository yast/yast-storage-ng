#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

require "y2storage/proposal_settings"
require "y2storage/partition_tables/type"
require "y2storage/filesystems/type"

RSpec.shared_context "boot requirements" do
  def find_vol(mount_point, volumes)
    volumes.find { |p| p.mount_point == mount_point }
  end

  subject(:checker) { described_class.new(fake_devicegraph) }

  let(:power_nv) { false }
  let(:efiboot) { false }

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
end
