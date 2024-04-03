#!/usr/bin/env rspec

# Copyright (c) [2024] SUSE LLC
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
    let(:control_file_content) { { "partitioning" => { "proposal" => {}, "volumes" => volumes } } }
    let(:volumes) { [root_vol, swap_vol] }
    let(:root_vol) do
      { "mount_point" => "/", "fs_type" => "xfs", "min_size" => "30 GiB" }
    end
    let(:swap_vol) do
      { "mount_point" => "swap", "fs_type" => "swap", "min_size" => "1 GiB", "max_size" => "2 GiB" }
    end

    let(:scenario) { "mixed_disks" }

    before do
      # Speed-up things by avoiding calls to hwinfo
      allow_any_instance_of(Y2Storage::Disk).to receive(:hwinfo).and_return(Y2Storage::HWInfoDisk.new)

      # Remove existing mount points, this is a new installation
      fake_devicegraph.mount_points.each { |i| i.parents.first.remove_mount_point }

      settings.space_settings.strategy = :bigger_resize
      # Agama uses homogeneous weights for all volumes
      settings.volumes.each { |v| v.weight = 100 }
      # Activate support for separate LVM VGs
      settings.separate_vgs = true
    end

    context "when there are resize actions for a disk that already contains the needed space" do
      let(:resize_info) do
        instance_double("Y2Storage::ResizeInfo", resize_ok?: true, reasons: 0, reason_texts: [],
          min_size: Y2Storage::DiskSize.GiB(40), max_size: Y2Storage::DiskSize.GiB(200))
      end

      let(:lvm) { true }

      before do
        settings.candidate_devices = ["/dev/sdb"]
        settings.root_device = "/dev/sda"
        settings.space_settings.actions = { "/dev/sda1" => :resize, "/dev/sda2" => :resize }
        allow(storage_arch).to receive(:efiboot?).and_return(true)
      end

      # This used to fail when evaluating the resize actions at sda1 and/or sda2, although
      # those actions are not really needed to allocate /boot/efi (the only partition that
      # needs to get created at sda).
      it "does not crash" do
        expect { proposal.propose }.to_not raise_error
      end
    end
  end
end
