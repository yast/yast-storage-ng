#!/usr/bin/env rspec
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
require "storage"
require "y2storage"
require_relative "#{TEST_PATH}/support/proposal_examples"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::GuidedProposal do
  describe "#propose" do
    include_context "proposal"

    subject(:proposal) { described_class.new(settings:) }
    let(:architecture) { :x86 }
    let(:settings_format) { :ng }
    let(:control_file) { "separate_vgs.xml" }
    let(:scenario) { "empty_disks" }
    before do
      settings.separate_vgs = separate_vgs

      root_vol = settings.volumes.find { |vol| vol.mount_point == "/" }
      root_vol.fs_type = Y2Storage::Filesystems::Type::BTRFS
      root_vol.subvolumes = [
        Y2Storage::SubvolSpecification.new("home"), Y2Storage::SubvolSpecification.new("srv")
      ]
    end

    let(:mounted_devices) do
      Y2Storage::MountPoint.all(proposal.devices).map { |i| i.filesystem.blk_devices.first }.uniq
    end

    let(:root_fs) do
      Y2Storage::MountPoint.find_by_path(proposal.devices, "/").first.filesystem
    end

    let(:subvol_specs) { proposal.settings.volumes.flat_map(&:subvolumes) }
    let(:subvols) { root_fs.btrfs_subvolumes.reject { |s| s.path.empty? } }

    RSpec.shared_examples "duplicated mount paths" do
      it "does not duplicate mount points" do
        proposal.propose

        mount_paths = Y2Storage::MountPoint.all(proposal.devices).map(&:path)
        expect(mount_paths.size).to eq mount_paths.uniq.size
      end
    end

    RSpec.shared_examples "shadowed subvolumes" do
      it "does not create subvolumes that are shadowed" do
        proposal.propose

        expect(subvols.size).to be < subvol_specs.size
        expect(subvol_specs.map(&:path)).to include "srv"
        expect(subvols.map(&:path)).to_not include "srv"
      end

      include_examples "duplicated mount paths"
    end

    context "when ProposalSettings#lvm is set to true" do
      let(:lvm) { true }

      context "and ProposalSettings#separate_vgs is set to true" do
        let(:separate_vgs) { true }

        it "proposes an LVM VG for every separate volume and another for system volumes" do
          proposal.propose
          vgs = proposal.devices.lvm_vgs

          expect(vgs.map(&:vg_name)).to contain_exactly("system", "spacewalk", "srv_vg")
          is_lv = mounted_devices.map { |i| i.is?(:lvm_lv) }
          expect(is_lv).to all(eq(true))
        end

        # Regression tests for bug#1174475, the /srv subvol was created despite
        # being shadowed by the volume created in a separate LVM VG
        include_examples "shadowed subvolumes"

        # Just to make sure subvolumes are not considered as shadowed when they are not
        context "but the separate volumes are disabled" do
          before do
            settings.volumes.each { |vol| vol.proposed = !vol.separate_vg? }
          end

          it "creates all the subvolumes" do
            proposal.propose
            expect(subvols.size).to eq subvol_specs.size
          end

          include_examples "duplicated mount paths"
        end
      end

      context "but ProposalSettings#separate_vgs is set to false" do
        let(:separate_vgs) { false }

        it "proposes only the system LVM VG containing all logical volumes" do
          proposal.propose
          vgs = proposal.devices.lvm_vgs

          expect(vgs.size).to eq 1
          expect(vgs.first.vg_name).to eq "system"
          is_lv = mounted_devices.map { |i| i.is?(:lvm_lv) }
          expect(is_lv).to all(eq(true))
        end

        include_examples "shadowed subvolumes"
      end
    end

    context "when ProposalSettings#lvm is set to false" do
      let(:lvm) { false }

      context "but ProposalSettings#separate_vgs is set to true" do
        let(:separate_vgs) { true }

        it "proposes some system partitions plus an LVM VG for every separate volume" do
          proposal.propose
          vgs = proposal.devices.lvm_vgs

          expect(vgs.map(&:vg_name)).to contain_exactly("spacewalk", "srv_vg")
          lvs = mounted_devices.select { |i| i.is?(:lvm_lv) }
          partitions = mounted_devices.select { |i| i.is?(:partition) }
          expect(lvs.size).to eq 2
          expect(partitions.size).to eq 2
        end

        include_examples "shadowed subvolumes"
      end

      context "and ProposalSettings#separate_vgs is set to false" do
        let(:separate_vgs) { false }

        it "proposes everything as partitions with no LVM VGs" do
          proposal.propose
          vgs = proposal.devices.lvm_vgs

          expect(vgs).to be_empty
          is_partition = mounted_devices.map { |i| i.is?(:partition) }
          expect(is_partition).to all(eq(true))
        end

        include_examples "shadowed subvolumes"
      end
    end
  end
end
