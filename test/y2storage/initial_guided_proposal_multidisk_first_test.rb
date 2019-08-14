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

  def used_devices
    sids_before = fake_devicegraph.partitions.map(&:sid)

    new_partitions = proposal.devices.partitions.reject { |p| sids_before.include?(p.sid) }
    devices = new_partitions.map(&:partitionable).uniq

    devices.map(&:name)
  end

  def proposed_vg_names
    proposal.planned_devices.map do |planned_device|
      next unless planned_device.is_a?(Y2Storage::Planned::LvmVg)

      planned_device.volume_group_name
    end
  end

  subject(:proposal) { described_class.new(settings: settings) }

  describe "#propose" do
    let(:sda) { fake_devicegraph.find_by_name("/dev/sda") }
    let(:sdb) { fake_devicegraph.find_by_name("/dev/sdb") }
    let(:sdc) { fake_devicegraph.find_by_name("/dev/sdc") }
    let(:sdd) { fake_devicegraph.find_by_name("/dev/sdd") }

    let(:control_file_content) { ng_partitioning_section }
    let(:settings) { Y2Storage::ProposalSettings.new_for_current_product }
    let(:disk_analyzer) { Y2Storage::DiskAnalyzer.new(fake_devicegraph) }
    let(:architecture) { :x86 }

    let(:volumes_spec) do
      [
        {
          "mount_point"           => "/",
          "fs_type"               => "ext4",
          "desired_size"          => "30GiB",
          "min_size"              => "10GiB",
          "max_size"              => "100GiB",
          "separate_vg_name"      => "vg-root",
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
            "allocate_volume_mode" => allocate_mode,
            "separate_vgs"         => separate_vgs
          },
          "volumes"  => volumes_spec
        }
      }
    end

    let(:separate_vgs) { false }

    let(:sda_size) { 45.GiB }
    let(:sdb_size) { 40.GiB }
    let(:sdc_size) { 9.GiB }
    let(:sdd_size) { 35.GiB }

    before do
      Y2Storage::StorageManager.create_test_instance
      Yast::ProductFeatures.Import(control_file_content)

      allow(Yast::Arch).to receive(:x86_64).and_return(architecture == :x86)
      allow(Yast::Arch).to receive(:i386).and_return(architecture == :i386)
      allow(Yast::Arch).to receive(:s390).and_return(architecture == :s390)
      allow(Y2Storage::DiskAnalyzer).to receive(:new).and_return disk_analyzer

      create_empty_disk("/dev/sda", sda_size)
      create_empty_disk("/dev/sdb", sdb_size)
      create_empty_disk("/dev/sdc", sdc_size)
      create_empty_disk("/dev/sdd", sdd_size)

      settings.lvm = lvm
    end

    context "when the proposal is set to use a multidisk_first approach" do
      shared_examples "make a proposal using as much devices as possible" do
        context "having enough space for the full proposal" do
          it "spreads the proposal as much as possible" do
            proposal.propose

            expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb", "/dev/sdd")
          end

          it "proposes also configurable volumes" do
            proposal.propose

            expect(proposed_vg_names).to include("vg-foobar")
          end
        end

        context "having space only for the minimal proposal" do
          let(:sda_size) { 11.GiB }
          let(:sdb_size) { 1.GiB }
          let(:sdd_size) { 11.GiB }

          it "spreads the proposal as much as possible" do
            proposal.propose

            expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdd")
          end

          it "proposes only required volumes" do
            proposal.propose

            expect(proposed_vg_names).to_not include("vg-pgsql")
          end
        end
      end

      context "and allocate_volume_mode set to :device" do
        let(:allocate_mode) { :device }

        context "using LVM" do
          let(:lvm) { true }

          context "with separated volume groups" do
            let(:separate_vgs) { true }

            include_examples "make a proposal using as much devices as possible"
          end

          context "without separated volume groups" do
            let(:separate_vgs) { false }

            # NOTE: even setting the allocate_device_mode to :device, the
            # proposal will use only one device when separated volumes are not
            # required.
            context "and some devices has enough space to hold the proposal" do
              let(:sdc_size) { 500.GiB }

              it "makes the proposal using the biggest one" do
                proposal.propose

                expect(used_devices).to contain_exactly("/dev/sdc")
              end
            end

            context "and none device has enough space to hold the proposal" do
              let(:sda_size) { 5.GiB }
              let(:sdb_size) { 5.GiB }
              let(:sdc_size) { 5.GiB }
              let(:sdd_size) { 5.GiB }

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

            include_examples "make a proposal using as much devices as possible"
          end

          context "without separated volume groups" do
            let(:separate_vgs) { false }

            it "spreads the proposal as much as possible" do
              proposal.propose

              expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb", "/dev/sdd")
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

            it "spreads the proposal as much as possible" do
              proposal.propose

              expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb", "/dev/sdd")
            end
          end

          context "without separated volume groups" do
            let(:separate_vgs) { false }

            it "only use necessary devices" do
              proposal.propose

              expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb")
            end
          end
        end

        context "not using LVM" do
          let(:lvm) { false }

          context "with separated volume groups" do
            let(:separate_vgs) { true }

            context "and there is room for the full proposal in a single device" do
              let(:sdb_size) { 500.GiB }

              it "makes the full proposal using a single device" do
                proposal.propose

                expect(used_devices).to contain_exactly("/dev/sdb")
              end
            end

            # NOTE: with current settings, a minimal proposal fits in sda, sdb or sdd
            context "and there is room for a minimal proposal in a single device" do
              it "makes the full proposal" do
                proposal.propose

                expect(proposed_vg_names).to include("vg-foobar")
              end

              it "uses multiple disks" do
                proposal.propose

                expect(used_devices.count).to be > 1
              end
            end

            context "but there is only room for the minimal proposal" do
              let(:sda_size) { 11.GiB }
              let(:sdb_size) { 11.GiB }
              let(:sdd_size) { 5.GiB }

              it "makes the minimal proposal" do
                proposal.propose

                expect(proposed_vg_names).to_not include("vg-foobar")
              end

              it "uses multiple disks" do
                proposal.propose

                expect(used_devices.count).to be > 1
              end
            end
          end

          context "without separated volume groups" do
            let(:separate_vgs) { false }

            context "and there is room for the full proposal" do
              let(:sda_size) { 20.GiB }
              let(:sdb_size) { 65.GiB }
              let(:sdd_size) { 11.GiB }

              it "makes the full proposal using necessary devices" do
                proposal.propose

                expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb")
                expect(proposal.planned_devices.map(&:mount_point)).to include("/foo/bar")
              end
            end

            context "but there is only room for the minimal proposal" do
              let(:sda_size) { 11.GiB }
              let(:sdb_size) { 11.GiB }
              let(:sdd_size) { 5.GiB }

              it "makes the minimal proposal using necessary devices" do
                proposal.propose

                expect(proposal.planned_devices.map(&:mount_point)).to_not include("/foo/bar")
                expect(used_devices.count).to be > 1
              end
            end
          end
        end
      end
    end
  end
end
