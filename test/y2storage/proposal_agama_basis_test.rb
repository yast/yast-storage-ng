#!/usr/bin/env rspec
# Copyright (c) [2023] SUSE LLC
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
require_relative "#{TEST_PATH}/support/proposal_examples"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::MinGuidedProposal do
  describe "#propose with settings in the Agama style" do
    subject(:proposal) { described_class.new(settings: settings) }

    include_context "proposal"
    let(:architecture) { :x86 }
    let(:settings_format) { :ng }
    let(:separate_home) { true }
    let(:control_file_content) do
      { "partitioning" => { "proposal" => { "windows_delete_mode" => :none }, "volumes" => volumes } }
    end

    # Several disks fully used by Windows partitions
    let(:scenario) { "windows_disks" }
    let(:resize_info) do
      instance_double("Y2Storage::ResizeInfo", resize_ok?: true, reasons: 0, reason_texts: [],
        min_size: Y2Storage::DiskSize.GiB(40), max_size: Y2Storage::DiskSize.TiB(2))
    end

    # Let's define some volumes to shuffle them around among the disks
    let(:volumes) { [root_vol, home_vol, srv_vol, swap_vol] }
    let(:root_vol) do
      { "mount_point" => "/", "fs_type" => "xfs", "min_size" => "10 GiB", "max_size" => "30 GiB" }
    end
    let(:home_vol) do
      { "mount_point" => "/home", "fs_type" => "xfs", "min_size" => "15 GiB" }
    end
    let(:srv_vol) do
      { "mount_point" => "/srv", "fs_type" => "xfs", "min_size" => "5 GiB", "max_size" => "10 GiB" }
    end
    let(:swap_vol) do
      { "mount_point" => "swap", "fs_type" => "swap", "min_size" => "1 GiB", "max_size" => "2 GiB" }
    end

    before do
      # Speed-up things by avoiding calls to hwinfo
      allow_any_instance_of(Y2Storage::Disk).to receive(:hwinfo).and_return(Y2Storage::HWInfoDisk.new)

      # Install into /dev/sdb by default
      settings.candidate_devices = ["/dev/sdb"]
      settings.root_device = "/dev/sdb"

      # Agama uses homogeneous weights for all volumes
      settings.volumes.each { |v| v.weight = 100 }
      # Activate support for separate LVM VGs
      settings.separate_vgs = true
    end

    context "when ProposalSettings#lvm is set to false" do
      let(:lvm) { false }

      context "if no alternative disks are specified for any of the volumes" do
        let(:expected_scenario_filename) { "agama-basis-single_disk" }

        # Creates all partitions in the target disk and leaves everything else untouched
        include_examples "proposed layout"
      end

      context "if some partitions are assigned to different disks" do
        let(:expected_scenario_filename) { "agama-basis-distributed" }

        before do
          settings.volumes.each do |vol|
            vol.device = "/dev/sda" if vol.mount_point == "/home"
            vol.device = "/dev/sdc" if vol.mount_point == "/srv"
          end
        end

        # Creates default partitions in the target disk and special ones at sda and sdc as requested
        include_examples "proposed layout"
      end

      context "if all partitions (even the root one) are assigned to a different disk" do
        let(:expected_scenario_filename) { "agama-basis-separate_boot" }

        before { settings.volumes.each { |v| v.device = "/dev/sda" } }

        # Creates all partitions at sda except the bios_boot one (at sdb)
        include_examples "proposed layout"
      end
    end

    context "when ProposalSettings#lvm is set to true" do
      let(:lvm) { true }

      context "if all volumes must be located in the system VG" do
        before do
          settings.volumes.each { |v| v.separate_vg_name = nil }
        end

        context "and the system VG must be located in the boot disk" do
          let(:expected_scenario_filename) { "agama-basis-lvm-single_disk" }

          # Creates the boot partition and the system VG with all volumes at the target disk
          include_examples "proposed layout"
        end

        context "and the system VG is allowed to use several disks" do
          before { settings.candidate_devices = ["/dev/sdb", "/dev/sdc"] }

          context "if all volumes fit when using only a disk" do
            let(:expected_scenario_filename) { "agama-basis-lvm-single_disk" }

            # Creates the boot partition and the system VG with all volumes at the target disk
            include_examples "proposed layout"
          end

          context "if several disks must be used for the volumes to fit" do
            before do
              root = settings.volumes.find { |v| v.mount_point == "/" }
              root.min_size = Y2Storage::DiskSize.GiB(380)
              root.max_size = Y2Storage::DiskSize.GiB(380)
            end

            let(:expected_scenario_filename) { "agama-basis-lvm-several_disks" }

            # Creates the system VG with all volumes over the needed candidate disks
            # FIXME: due to bsc#1211041, this resizes sdc1 to its minimum and consequently creates
            # bigger LVs for swap, /srv or /home than the other LVM-based contexts
            include_examples "proposed layout"
          end
        end

        context "and the system VG must be located in another disk (not the boot one)" do
          before { settings.candidate_devices = ["/dev/sdc"] }

          let(:expected_scenario_filename) { "agama-basis-lvm-separate_boot" }

          # Creates the system VG at sdc and the partition needed for booting at sdb
          include_examples "proposed layout"
        end
      end

      context "if some volumes must be located in their own separate VG" do
        before do
          settings.volumes.each do |vol|
            case vol.mount_point
            when "/home"
              vol.separate_vg_name = "home"
              vol.device = "/dev/sda"
            when "/srv"
              vol.separate_vg_name = "srv"
              vol.device = "/dev/sdc"
            end
          end
        end

        let(:expected_scenario_filename) { "agama-basis-lvm-distributed" }

        # Creates the system VG in the target disk and separate ones at sda and sdc as requested
        include_examples "proposed layout"
      end
    end
  end
end
