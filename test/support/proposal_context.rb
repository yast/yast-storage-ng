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

require "storage"
require "y2storage"

RSpec.shared_context "proposal" do
  using Y2Storage::Refinements::TestDevicegraph
  using Y2Storage::Refinements::SizeCasts
  using Y2Storage::Refinements::DevicegraphLists

  before do
    fake_scenario(scenario)

    allow(Y2Storage::DiskAnalyzer).to receive(:new).and_return disk_analyzer
    allow(disk_analyzer).to receive(:windows_partition?) do |partition|
      !!(partition.filesystem.label =~ /indows/)
    end

    allow_any_instance_of(::Storage::Filesystem).to receive(:detect_resize_info)
      .and_return(resize_info)

    allow(Yast::Arch).to receive(:x86_64).and_return true
    allow(Y2Storage::StorageManager.instance).to receive(:arch).and_return(storage_arch)
    allow(storage_arch).to receive(:efiboot?).and_return(false)
    allow(storage_arch).to receive(:x86?).and_return(true)
    allow(storage_arch).to receive(:ppc?).and_return(false)
    allow(storage_arch).to receive(:s390?).and_return(false)
  end

  subject(:proposal) { Y2Storage::Proposal.new(settings: settings) }

  let(:disk_analyzer) { Y2Storage::DiskAnalyzer.new(fake_devicegraph, scope: :install_candidates) }
  let(:storage_arch) { instance_double("::Storage::Arch") }
  let(:resize_info) do
    instance_double("::Storage::ResizeInfo", resize_ok: true, min_size: 40.GiB.to_i)
  end
  let(:separate_home) { false }
  let(:lvm) { false }
  let(:settings) do
    settings = Y2Storage::ProposalSettings.new
    settings.use_separate_home = separate_home
    settings.use_lvm = lvm
    settings
  end
end
