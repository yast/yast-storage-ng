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

require_relative "spec_helper"
require "storage"
require "y2storage"

# To avoid repeating this four lines of code all over the file
RSpec.shared_examples "proposed layout" do
  using Y2Storage::Refinements::TestDevicegraph

  it "proposes the expected layout" do
    proposal.propose
    expect(proposal.devices.to_str).to eq expected.to_str
  end
end

describe Y2Storage::Proposal do
  describe "#propose" do
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

    subject(:proposal) { described_class.new(settings: settings) }

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

    let(:expected) do
      file_name = scenario
      file_name.concat("-lvm") if lvm
      file_name.concat("-sep-home") if separate_home
      ::Storage::Devicegraph.new_from_file(output_file_for(file_name))
    end

    context "in a windows-only PC" do
      let(:scenario) { "windows-pc" }

      context "using LVM" do
        let(:lvm) { true }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end

      context "not using LVM" do
        let(:lvm) { false }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end
    end

    context "in a windows/linux multiboot PC" do
      let(:scenario) { "windows-linux-multiboot-pc" }

      context "using LVM" do
        let(:lvm) { true }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end

      context "not using LVM" do
        let(:lvm) { false }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end
    end

    context "in a linux multiboot PC" do
      let(:scenario) { "multi-linux-pc" }
      let(:windows_partitions) { {} }

      context "using LVM" do
        let(:lvm) { true }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end

      context "not using LVM" do
        let(:lvm) { false }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end
    end

    context "in a windows/linux multiboot PC with pre-existing LVM" do
      let(:scenario) { "windows-linux-lvm-pc" }

      context "using LVM" do
        let(:lvm) { true }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end

      context "not using LVM" do
        let(:lvm) { false }

        context "with a separate home" do
          let(:separate_home) { true }
          include_examples "proposed layout"
        end

        context "without separate home" do
          let(:separate_home) { false }
          include_examples "proposed layout"
        end
      end
    end

    context "with pre-existing swap partitions" do
      before do
        allow(Y2Storage::Proposal::VolumesGenerator).to receive(:new).and_return volumes_generator
        settings.root_device = "/dev/sda"
      end

      let(:scenario) { "swaps" }
      let(:windows_partitions) { {} }
      let(:volumes_generator) do
        base_volumes = [
          planned_vol(mount_point: "/", type: :ext4, desired: 500.MiB, max: 500.MiB)
        ]
        all_volumes = [
          planned_vol(mount_point: "/", type: :ext4, desired: 500.MiB, max: 500.MiB),
          planned_vol(mount_point: "swap", reuse: "/dev/sda3"),
          planned_vol(mount_point: "swap", type: :swap, desired: 500.MiB, max: 500.MiB),
          planned_vol(mount_point: "swap", type: :swap, desired: 500.MiB, max: 500.MiB),
          planned_vol(mount_point: "swap", type: :swap, desired: 500.MiB, max: 500.MiB)
        ]
        instance_double(
          "Y2Storage::Proposal::VolumesGenerator",
          base_volumes: Y2Storage::PlannedVolumesList.new(base_volumes),
          all_volumes:  Y2Storage::PlannedVolumesList.new(all_volumes)
        )
      end

      it "reuses suitable swap partitions" do
        proposal.propose
        sda3 = proposal.devices.partitions.with(name: "/dev/sda3").first
        expect(sda3).to match_fields(
          mountpoint: "swap",
          uuid:       "33333333-3333-3333-3333-33333333",
          label:      "swap3",
          size:       (1.GiB - 1.MiB).to_i
        )
      end

      it "reuses UUID and label of deleted swap partitions" do
        proposal.propose
        sda2 = proposal.devices.partitions.with(name: "/dev/sda2").first
        expect(sda2).to match_fields(
          mountpoint: "swap",
          uuid:       "11111111-1111-1111-1111-11111111",
          label:      "swap1",
          size:       500.MiB.to_i
        )
        sda5 = proposal.devices.partitions.with(name: "/dev/sda5").first
        expect(sda5).to match_fields(
          mountpoint: "swap",
          uuid:       "22222222-2222-2222-2222-22222222",
          label:      "swap2",
          size:       500.MiB.to_i
        )
      end

      it "does not enforce any particular UUID or label for additional swaps" do
        proposal.propose
        sda6 = proposal.devices.partitions.with(name: "/dev/sda6").first
        expect(sda6).to match_fields(mountpoint: "swap", uuid: "", label: "")
      end
    end
  end
end
