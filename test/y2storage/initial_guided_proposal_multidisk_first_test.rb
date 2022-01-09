#!/usr/bin/env ruby
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

describe Y2Storage::InitialGuidedProposal do
  using Y2Storage::Refinements::SizeCasts

  def created_mount_paths
    created_partitions.map(&:filesystem).compact.map(&:mount_path)
  end

  def created_partitions
    proposal.devices.partitions
  end

  def created_vgs
    proposal.devices.lvm_vgs
  end

  def created_vgs_names
    proposal.devices.lvm_vgs.map(&:vg_name)
  end

  def device_used_by(element)
    case element
    when Y2Storage::Partition
      element.partitionable
    when Y2Storage::LvmVg
      element.lvm_pvs.map(&:blk_device).map(&:partitionable)
    end
  end

  def used_devices
    sids_before = fake_devicegraph.partitions.map(&:sid)

    new_partitions = proposal.devices.partitions.reject { |p| sids_before.include?(p.sid) }
    devices = new_partitions.map(&:partitionable).uniq

    devices.map(&:name)
  end

  subject(:proposal) { described_class.new(settings: settings) }

  describe "#propose (with multidisk_first set to true)" do
    let(:sda) { fake_devicegraph.find_by_name("/dev/sda") }
    let(:sdb) { fake_devicegraph.find_by_name("/dev/sdb") }
    let(:sdc) { fake_devicegraph.find_by_name("/dev/sdc") }
    let(:sdd) { fake_devicegraph.find_by_name("/dev/sdd") }
    let(:control_file_content) { ng_partitioning_section }

    let(:settings) { Y2Storage::ProposalSettings.new_for_current_product }
    let(:disk_analyzer) { Y2Storage::DiskAnalyzer.new(fake_devicegraph) }

    let(:volumes_spec) do
      [
        {
          "mount_point"           => "/",
          "fs_type"               => "ext4",
          "desired_size"          => "30GiB",
          "min_size"              => "10GiB",
          "max_size"              => "100GiB",
          "proposed_configurable" => false
        },
        {
          "mount_point"           => "/home",
          "fs_type"               => "xfs",
          "desired_size"          => "30GiB",
          "min_size"              => "10GiB",
          "max_size"              => "100GiB",
          "separate_vg_name"      => "vg-home",
          "proposed_configurable" => false
        },
        {
          "mount_point"           => "/foo/bar",
          "fs_type"               => "xfs",
          "desired_size"          => "15GiB",
          "min_size"              => "10GiB",
          "max_size"              => "100GiB",
          "separate_vg_name"      => "vg-foobar",
          "disable_order"         => 1,
          "proposed_configurable" => true
        }
      ]
    end

    let(:ng_partitioning_section) do
      {
        "partitioning" => {
          "proposal" => {
            "multidisk_first"      => true,
            "lvm_vg_strategy"      => :use_needed,
            "allocate_volume_mode" => allocate_mode
          },
          "volumes"  => volumes_spec
        }
      }
    end

    let(:separate_vgs) { false }

    before do
      Y2Storage::StorageManager.create_test_instance
      Yast::ProductFeatures.Import(control_file_content)

      allow(Yast::Arch).to receive(:x86_64).and_return(true)
      allow(Y2Storage::DiskAnalyzer).to receive(:new).and_return disk_analyzer

      create_empty_disk("/dev/sda", sda_size)
      create_empty_disk("/dev/sdb", sdb_size)
      create_empty_disk("/dev/sdc", sdc_size)
      create_empty_disk("/dev/sdd", sdd_size)

      settings.lvm = lvm
      settings.separate_vgs = separate_vgs
    end

    context "when allocate_volume_mode set to :device" do
      let(:allocate_mode) { :device }

      context "using LVM" do
        let(:lvm) { true }

        context "with separated volume groups" do
          let(:separate_vgs) { true }

          context "having enough room for a full proposal" do
            let(:sda_size) { 100.GiB }
            let(:sdb_size) { 100.GiB }
            let(:sdc_size) { 100.GiB }
            let(:sdd_size) { 100.GiB }

            it "assings each volume to a different device" do
              proposal.propose

              root = created_vgs.find { |vg| vg.vg_name == "system" }
              home = created_vgs.find { |vg| vg.vg_name == "vg-home" }
              foobar = created_vgs.find { |vg| vg.vg_name == "vg-foobar" }

              devices = [root, home, foobar].map { |i| device_used_by(i) }.compact.uniq

              expect(devices.size).to eq(3)
            end

            it "creates all volumes, including optional ones" do
              proposal.propose

              expect(created_vgs_names).to contain_exactly("system", "vg-home", "vg-foobar")
            end
          end

          context "having space only for a minimal proposal" do
            let(:sda_size) { 15.GiB }
            let(:sdb_size) { 15.GiB }
            let(:sdc_size) { 5.GiB }
            let(:sdd_size) { 5.GiB }

            it "assings each volume to a different device" do
              proposal.propose

              root = created_vgs.find { |vg| vg.vg_name == "system" }
              home = created_vgs.find { |vg| vg.vg_name == "vg-home" }
              foobar = created_vgs.find { |vg| vg.vg_name == "vg-foobar" }

              devices = [root, home, foobar].map { |i| device_used_by(i) }.compact.uniq

              expect(devices.size).to eq(2)
            end

            it "creates only mandatory volumes" do
              proposal.propose

              expect(created_vgs_names).to contain_exactly("system", "vg-home")
            end
          end
        end

        context "without separated volume groups" do
          let(:separate_vgs) { false }

          # NOTE: when separated volumes are not required, the proposal will create only
          # the "system" LVM VG in a single device.
          context "and having some devices with enough space to hold the proposal" do
            let(:sda_size) { 20.GiB }
            let(:sdb_size) { 20.GiB }
            let(:sdc_size) { 40.GiB }
            let(:sdd_size) { 80.GiB }

            it "makes the proposal using only a single device" do
              proposal.propose

              # sda and sdb are too small to hold the proposal
              expect(used_devices).to contain_exactly("/dev/sdc")
            end

            it "creates only the 'system' LVM VG" do
              proposal.propose

              expect(created_vgs_names).to contain_exactly("system")
            end
          end

          context "and none device has enough space to hold the proposal" do
            let(:sda_size) { 20.GiB }
            let(:sdb_size) { 20.GiB }
            let(:sdc_size) { 20.GiB }
            let(:sdd_size) { 20.GiB }

            it "raises a NoDiskSpaceError (although all devices together could hold it)" do
              expect { proposal.propose }.to raise_exception(Y2Storage::NoDiskSpaceError)
            end
          end
        end
      end

      context "not using LVM" do
        let(:lvm) { false }

        context "with separated volume groups" do
          let(:separate_vgs) { true }

          context "having enough room for a full proposal" do
            let(:sda_size) { 40.GiB }
            let(:sdb_size) { 40.GiB }
            let(:sdc_size) { 25.GiB }
            let(:sdd_size) { 20.GiB }

            it "creates partitions for all volumes without separate_vg_name" do
              proposal.propose

              expect(created_mount_paths).to include("/")
            end

            it "creates LVM VGs for all volumes with separate_vg_name" do
              proposal.propose

              expect(created_vgs_names).to contain_exactly("vg-home", "vg-foobar")
            end

            it "assings each volume to a different device" do
              proposal.propose

              root = created_partitions.find { |p| p&.filesystem&.mount_path == "/" }
              home = created_vgs.find { |vg| vg.vg_name == "vg-home" }
              foobar = created_vgs.find { |vg| vg.vg_name == "vg-foobar" }

              devices = [root, home, foobar].map { |i| device_used_by(i) }.compact.uniq

              expect(devices.size).to eq(3)
            end
          end

          context "having space only for a minimal proposal" do
            let(:sda_size) { 15.GiB }
            let(:sdb_size) { 15.GiB }
            let(:sdc_size) { 15.GiB }
            let(:sdd_size) { 5.GiB }

            it "creates as partition all volumes without separate_vg_name" do
              proposal.propose

              expect(created_mount_paths).to include("/")
            end

            it "creates as LVM VG all volumes with separate_vg_name" do
              proposal.propose

              expect(created_vgs_names).to contain_exactly("vg-home", "vg-foobar")
            end

            it "uses as much devices as posible" do
              proposal.propose

              expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb", "/dev/sdc")
            end
          end
        end

        context "without separated volume groups" do
          let(:separate_vgs) { false }

          let(:sda_size) { 100.GiB }
          let(:sdb_size) { 100.GiB }
          let(:sdc_size) { 100.GiB }
          let(:sdd_size) { 100.GiB }

          it "creates partitions for all volumes" do
            proposal.propose

            expect(created_mount_paths).to contain_exactly("/", "/home", "/foo/bar")
          end

          it "assings each volume to a different device" do
            proposal.propose

            root = created_partitions.find { |p| p&.filesystem&.mount_path == "/" }
            home = created_partitions.find { |p| p&.filesystem&.mount_path == "/home" }
            foobar = created_partitions.find { |p| p&.filesystem&.mount_path == "/foo/bar" }

            devices = [root, home, foobar].map(&:partitionable).uniq

            expect(devices.size).to eq(3)
          end
        end
      end
    end

    # NOTE: this scenario, multidisk_first + allocate_volume_mode :auto, is
    # a kind of "fallback" to the behavior of the initial proposal before
    # changes introduced in https://github.com/yast/yast-storage-ng/pull/783
    context "with allocate_volume_mode set to :auto" do
      let(:allocate_mode) { :auto }

      context "using LVM" do
        let(:lvm) { true }

        context "with separated volume groups" do
          let(:separate_vgs) { true }

          context "and it fits in only one device" do
            let(:sda_size) { 40.GiB }
            let(:sdb_size) { 80.GiB }
            let(:sdc_size) { 20.GiB }
            let(:sdd_size) { 20.GiB }

            it "creates all LVM VGs" do
              proposal.propose

              expect(created_vgs_names).to contain_exactly("system", "vg-home", "vg-foobar")
            end

            it "creates a proposal that uses the first devices as needed" do
              proposal.propose

              expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb")
            end
          end

          context "and it does not fit in a single device" do
            # The minimal proposal including all volumes needs 30GiB
            let(:sda_size) { 10.GiB }
            let(:sdb_size) { 10.GiB }
            let(:sdc_size) { 10.GiB }
            let(:sdd_size) { 10.GiB }

            # FIXME: it seems that SpaceMaker is having troubles to assign
            # space at the time to create multiple LVM VGs when
            # allocate_volume_mode => :auto and separate_vgs => true
            xit "creates all LVM VGs" do
              proposal.propose

              expect(created_vgs_names).to contain_exactly("system", "vg-home", "vg-foobar")
            end

            # FIXME: it seems that SpaceMaker is having troubles to assign
            # space at the time to create multiple LVM VGs when
            # allocate_volume_mode => :auto and separate_vgs => true
            xit "creates the proposal using needed devices" do
              proposal.propose

              expect(used_devices)
                .to contain_exactly("/dev/sda", "/dev/sdb", "/dev/sdc", "/dev/sdd")
            end
          end
        end

        context "without separated volume groups" do
          let(:separate_vgs) { false }

          context "and it fits in only one device" do
            let(:sda_size) { 40.GiB }
            let(:sdb_size) { 80.GiB }
            let(:sdc_size) { 20.GiB }
            let(:sdd_size) { 20.GiB }

            it "creates only the system LVM VG" do
              proposal.propose

              system = proposal.devices.lvm_vgs.find { |v| v.vg_name == "system" }
              mount_points = system.lvm_lvs.map { |l| l.filesystem.mount_path }

              expect(mount_points).to contain_exactly("/", "/home", "/foo/bar")
            end

            it "creates a proposal that uses the first devices as needed" do
              proposal.propose

              expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb")
            end
          end

          context "and it does not fit in a single device" do
            # The minimal proposal including all volumes needs 30GiB
            let(:sda_size) { 10.GiB }
            let(:sdb_size) { 6.GiB }
            let(:sdc_size) { 6.GiB }
            let(:sdd_size) { 10.GiB }

            it "creates only the system LVM VG" do
              proposal.propose

              expect(created_vgs_names).to contain_exactly("system")
            end

            it "creates the proposal using needed devices" do
              proposal.propose

              expect(used_devices)
                .to contain_exactly("/dev/sda", "/dev/sdb", "/dev/sdc", "/dev/sdd")
            end
          end
        end
      end

      context "not using LVM" do
        let(:lvm) { false }

        context "with separated volume groups" do
          let(:separate_vgs) { true }

          context "and it fits in only one device" do
            let(:sda_size) { 40.GiB }
            let(:sdb_size) { 80.GiB }
            let(:sdc_size) { 20.GiB }
            let(:sdd_size) { 20.GiB }

            it "creates partitions for all volumes without separate_vg_name" do
              proposal.propose

              expect(created_mount_paths).to include("/")
            end

            it "creates LVM VGs for volumes with separate_vg_name" do
              proposal.propose

              expect(created_vgs_names).to contain_exactly("vg-home", "vg-foobar")
            end

            # FIXME: it seems that SpaceMaker is having troubles to assign
            # space at the time to create multiple LVM VGs when
            # allocate_volume_mode => :auto and separate_vgs => true
            xit "uses only needed devices" do
              proposal.propose

              expect(used_devices).to contain_exactly("/dev/sdb")
            end
          end

          context "and it does not fit in a single device" do
            # The minimal proposal including all volumes needs 30GiB
            let(:sda_size) { 8.GiB }
            let(:sdb_size) { 8.GiB }
            let(:sdc_size) { 10.GiB }
            let(:sdd_size) { 11.GiB }

            # FIXME: it seems that SpaceMaker is having troubles to assign
            # space at the time to create multiple LVM VGs when
            # allocate_volume_mode => :auto and separate_vgs => true
            xit "creates partitions all volumes without separate_vg_name" do
              proposal.propose

              expect(created_mount_paths).to include("/")
            end

            # FIXME: it seems that SpaceMaker is having troubles to assign
            # space at the time to create multiple LVM VGs when
            # allocate_volume_mode => :auto and separate_vgs => true
            xit "creates LVM VGs for volumes with separate_vg_name" do
              proposal.propose

              expect(created_vgs_names).to contain_exactly("vg-home", "vg-foobar")
            end

            # FIXME: it seems that SpaceMaker is having troubles to assign
            # space at the time to create multiple LVM VGs when
            # allocate_volume_mode => :auto and separate_vgs => true
            xit "creates the proposal using needed devices" do
              proposal.propose

              expect(used_devices)
                .to contain_exactly("/dev/sda", "/dev/sdb", "/dev/sdc", "/dev/sdd")
            end
          end
        end

        context "without separated volume groups" do
          let(:separate_vgs) { false }

          context "and the proposal fits in a single device" do
            let(:sda_size) { 10.GiB }
            let(:sdb_size) { 100.GiB }
            let(:sdc_size) { 10.GiB }
            let(:sdd_size) { 10.GiB }

            it "creates all volumes as partitions" do
              proposal.propose

              expect(created_mount_paths).to contain_exactly("/", "/home", "/foo/bar")
            end

            it "makes the proposal in a single device" do
              proposal.propose

              expect(used_devices).to contain_exactly("/dev/sdb")
            end
          end

          context "and the proposal does not fit in a single device" do
            # NOTE: it is needed to create three partitions of at least 10GiB plus the boot
            # partition
            let(:sda_size) { 30.GiB }
            let(:sdb_size) { 30.GiB }
            let(:sdc_size) { 5.GiB }
            let(:sdd_size) { 5.GiB }

            it "creates all volumes as partitions" do
              proposal.propose

              expect(created_mount_paths).to contain_exactly("/", "/home", "/foo/bar")
            end

            it "makes the proposal using needed devices" do
              proposal.propose

              expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb")
            end
          end
        end
      end
    end
  end
end
