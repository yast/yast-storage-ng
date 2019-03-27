#!/usr/bin/env rspec
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

RSpec.shared_context "proposal" do
  include Yast::Logger
  using Y2Storage::Refinements::SizeCasts

  before do
    fake_scenario(scenario)

    allow(Y2Storage::DiskAnalyzer).to receive(:new).and_return disk_analyzer
    allow(disk_analyzer).to receive(:windows_partition?) do |partition|
      partition.filesystem && !!(partition.filesystem.label =~ /indows/)
    end

    allow_any_instance_of(Y2Storage::Partition).to receive(:detect_resize_info)
      .and_return(resize_info)

    allow(Yast::Arch).to receive(:x86_64).and_return(architecture == :x86)
    allow(Yast::Arch).to receive(:i386).and_return(architecture == :i386)
    allow(Yast::Arch).to receive(:s390).and_return(architecture == :s390)
    allow(storage_arch).to receive(:ppc_power_nv?).and_return(ppc_power_nv)
    allow(Y2Storage::StorageManager.instance.storage).to receive(:arch).and_return(storage_arch)
    allow(storage_arch).to receive(:efiboot?).and_return(false)
    allow(storage_arch).to receive(:x86?).and_return(architecture == :x86)
    allow(storage_arch).to receive(:ppc?).and_return(architecture == :ppc)
    allow(storage_arch).to receive(:s390?).and_return(architecture == :s390)

    Yast::ProductFeatures.Import(control_file_content)

    allow(Yast::SCR).to receive(:Read).and_call_original

    allow(Yast::SCR).to receive(:Read).with(path(".proc.meminfo"))
      .and_return("memtotal" => memtotal)
  end

  let(:architecture) { :x86 }
  let(:ppc_power_nv) { false }

  let(:memtotal) { 8.GiB.to_i / 1.KiB.to_i }

  let(:disk_analyzer) { Y2Storage::DiskAnalyzer.new(fake_devicegraph) }
  let(:storage_arch) { instance_double("::Storage::Arch") }
  let(:resize_info) do
    instance_double("Y2Storage::ResizeInfo", resize_ok?: true, min_size: 40.GiB, max_size: 800.GiB,
      reasons: 0, reason_texts: [])
  end

  let(:settings_format) { :legacy }

  let(:settings) { settings_format == :legacy ? legacy_settings : ng_settings }

  let(:separate_home) { false }
  let(:lvm) { false }
  let(:lvm_strategy) { nil }
  let(:encrypt) { false }
  let(:test_with_subvolumes) { false }
  let(:legacy_settings) do
    settings = Y2Storage::ProposalSettings.new_for_current_product
    settings.use_separate_home = separate_home
    settings.use_lvm = lvm
    settings.encryption_password = encrypt ? "12345678" : nil
    # If subvolumes are not tested, override the subvolume fallbacks list
    settings.subvolumes = nil unless test_with_subvolumes
    settings
  end

  let(:ng_settings) do
    settings = Y2Storage::ProposalSettings.new_for_current_product
    home = settings.volumes.find { |v| v.mount_point == "/home" }
    home.proposed = separate_home if home
    settings.lvm = lvm
    if lvm && lvm_strategy
      settings.lvm_vg_strategy = lvm_strategy
    end
    settings.encryption_password = encrypt ? "12345678" : nil
    settings
  end

  let(:control_file) { nil }

  let(:control_file_content) do
    if control_file
      file = File.join(DATA_PATH, "control_files", control_file)
      Yast::XML.XMLToYCPFile(file)
    else
      {}
    end
  end

  let(:expected_scenario) { scenario }
  let(:expected) do
    file_name = expected_scenario
    file_name.concat("-enc") if encrypt
    if lvm
      file_name.concat("-lvm")
      file_name.concat("-#{lvm_strategy}") if lvm_strategy
    end
    file_name.concat("-sep-home") if separate_home
    full_path = output_file_for(file_name)
    devicegraph = Y2Storage::Devicegraph.new_from_file(full_path)
    log.info("Expected devicegraph from file\n#{full_path}:\n\n#{devicegraph.to_str}\n")
    devicegraph
  end

  def disk_for(mountpoint)
    proposal.devices.disks.detect do |disk|
      disk.partitions.any? { |p| p.filesystem_mountpoint == mountpoint }
    end
  end
end
