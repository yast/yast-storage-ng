#!/usr/bin/env rspec
# Copyright (c) [2018-2019] SUSE LLC
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
require_relative "#{TEST_PATH}/support/candidate_devices_context"

describe Y2Storage::InitialGuidedProposal do
  using Y2Storage::Refinements::SizeCasts

  include_context "proposal"

  let(:architecture) { :x86 }

  let(:scenario) { "empty_hard_disk_gpt_25GiB" }

  subject(:proposal) { described_class.new(settings: settings) }

  describe ".new" do
    context "when settings are not passed" do
      it "reads the settings for the current product (control.xml)" do
        expect(Y2Storage::ProposalSettings).to receive(:new_for_current_product)
          .and_call_original

        described_class.new(settings: nil)
      end
    end
  end

  describe "#propose" do
    let(:ng_partitioning_section) do
      {
        "partitioning" => {
          "proposal" => { "allocate_volume_mode" => allocate_mode },
          "volumes"  => volumes_spec
        }
      }
    end

    let(:allocate_mode) { :auto }

    let(:volumes_spec) do
      [
        {
          "mount_point"  => "/",
          "fs_type"      => "ext4",
          "desired_size" => "10GiB",
          "min_size"     => "8GiB",
          "max_size"     => "20GiB"
        },
        {
          "mount_point"  => "/home",
          "fs_type"      => "xfs",
          "desired_size" => "20GiB",
          "min_size"     => "10GiB",
          "max_size"     => "40GiB"
        },
        {
          "mount_point"           => "swap",
          "fs_type"               => "swap",
          "desired_size"          => "2GiB",
          "min_size"              => "1GiB",
          "max_size"              => "2GiB",
          "proposed_configurable" => swap_optional,
          "disable_order"         => 1
        }
      ]
    end

    let(:swap_optional) { true }

    context "when settings has legacy format" do
      it "uses the legacy settings generator to calculate the settings" do
        expect(Y2Storage::Proposal::SettingsGenerator::Legacy).to receive(:new).and_call_original

        proposal.propose
      end
    end

    context "when settings has ng format" do
      let(:control_file_content) { ng_partitioning_section }

      it "uses the ng settings generator to calculate the settings" do
        expect(Y2Storage::Proposal::SettingsGenerator::Ng).to receive(:new).and_call_original

        proposal.propose
      end
    end

    context "when no candidate devices are given" do
      include_context "candidate devices"

      let(:candidate_devices) { nil }

      let(:control_file_content) { ng_partitioning_section }

      let(:sda_usb) { true }

      shared_examples "no candidate devices" do
        it "uses the first non USB device to make the proposal" do
          proposal.propose

          expect(used_devices).to contain_exactly("/dev/sdb")
        end

        context "and a proposal is not possible with the current device" do
          before do
            # root requires at least 8 GiB and home 10 GiB
            sdb.size = 5.GiB
          end

          it "uses the next non USB device to make the proposal" do
            proposal.propose

            expect(used_devices).to contain_exactly("/dev/sdc")
          end
        end
      end

      context "with allocate_volume_mode set to :auto" do
        let(:allocate_mode) { :auto }

        include_examples "no candidate devices"
      end

      context "with allocate_volume_mode set to :device" do
        let(:allocate_mode) { :device }

        include_examples "no candidate devices"
      end

      context "and a proposal is not possible without USB devices" do
        let(:sda_usb) { false }
        let(:sdb_usb) { true }
        let(:sdc_usb) { true }

        before do
          # root requires at least 8 GiB and home 10 GiB
          sda.size = 10.GiB
        end

        shared_examples "no proposal without USB" do
          it "uses the first USB device to make a proposal" do
            proposal.propose

            expect(used_devices).to contain_exactly("/dev/sdb")
          end

          context "and a proposal is not possible with the current USB device" do
            before do
              # root requires at least 8 GiB and home 10 GiB
              sdb.size = 5.GiB
            end

            it "uses the next USB device to make the proposal" do
              proposal.propose

              expect(used_devices).to contain_exactly("/dev/sdc")
            end
          end
        end

        context "with allocate_volume_mode set to :auto" do
          let(:allocate_mode) { :auto }

          include_examples "no proposal without USB"
        end

        context "with allocate_volume_mode set to :device" do
          let(:allocate_mode) { :device }

          include_examples "no proposal without USB"
        end
      end

      context "and the proposal is set to use a multidisk_first approach" do
        let(:sda_usb) { false }
        let(:sdb_usb) { false }
        let(:sdc_usb) { false }
        let(:separate_vgs) { false }

        let(:volumes_spec) do
          [
            {
              "mount_point"           => "/",
              "fs_type"               => "ext4",
              "desired_size"          => "10GiB",
              "min_size"              => "10GiB",
              "max_size"              => "10GiB",
              "separate_vg_name"      => "vg-root",
              "proposed_configurable" => false
            },
            {
              "mount_point"           => "/home",
              "fs_type"               => "xfs",
              "desired_size"          => "10GiB",
              "min_size"              => "10GiB",
              "max_size"              => "10GiB",
              "separate_vg_name"      => "vg-home",
              "proposed_configurable" => false
            },
            {
              "mount_point"           => "/var/spacewalk",
              "fs_type"               => "xfs",
              "desired_size"          => "10GiB",
              "min_size"              => "10GiB",
              "max_size"              => "10GiB",
              "separate_vg_name"      => "vg-spacewalk",
              "proposed_configurable" => false
            },
            {
              "mount_point"           => "/var/lib/pgsql",
              "fs_type"               => "xfs",
              "desired_size"          => "10GiB",
              "min_size"              => "10GiB",
              "max_size"              => "10GiB",
              "separate_vg_name"      => "vg-pgsql",
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

        let(:proposed_vg_names) do
          proposal.planned_devices.map do |planned_device|
            next unless planned_device.is_a?(Y2Storage::Planned::LvmVg)

            planned_device.volume_group_name
          end
        end

        shared_examples "proposal in all possible devices" do
          context "having enough space for the full proposal" do
            before do
              sda.size = 100.GiB
              sdb.size = 100.GiB
              sdc.size = 100.GiB
            end

            it "spreads the proposal as much as possible" do
              proposal.propose

              expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb", "/dev/sdc")
            end

            it "proposes also configurable volumes" do
              proposal.propose

              expect(proposed_vg_names).to include("vg-pgsql")
            end
          end

          context "having space only for the minimal proposal" do
            before do
              sda.size = 11.GiB
              sdb.size = 11.GiB
              sdc.size = 11.GiB
            end

            it "spreads the proposal as much as possible" do
              proposal.propose

              expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb", "/dev/sdc")
            end

            it "proposes only required volumes" do
              proposal.propose

              expect(proposed_vg_names).to_not include("vg-pgsql")
            end
          end
        end

        context "with allocate_volume_mode set to :device" do
          let(:allocate_mode) { :device }

          context "using lvm" do
            let(:lvm) { true }

            context "with separated volume groups" do
              let(:separate_vgs) { true }

              include_examples "proposal in all possible devices"
            end

            context "without separated volume groups" do
              let(:separate_vgs) { false }

              # NOTE: even setting the allocate_device_mode to :device, the
              # proposal will use only one device when separated volumes are not
              # required.
              context "and some devices has enough space to hold the proposal" do
                before do
                  sda.size = 25.GiB
                  sdb.size = 100.GiB
                  sdc.size = 200.GiB
                end

                it "makes the proposal using the biggest one" do
                  proposal.propose

                  expect(used_devices).to contain_exactly("/dev/sdc")
                end
              end

              context "and none device has enough space to hold the proposal" do
                before do
                  sda.size = 20.GiB
                  sdb.size = 20.GiB
                  sdc.size = 20.GiB
                end

                it "raises a NoDiskSpaceError (although all devices together could hold it)" do
                  expect { proposal.propose }.to raise_exception(Y2Storage::NoDiskSpaceError)
                end
              end
            end
          end

          context "not using lvm" do
            let(:lvm) { false }

            before do
              sda.size = 12.GiB
              sdb.size = 120.GiB
              sdc.size = 1000.GiB
            end

            context "with separated volume groups" do
              let(:separate_vgs) { true }

              include_examples "proposal in all possible devices"
            end

            context "without separated volume groups" do
              let(:separate_vgs) { false }

              it "spreads the proposal as much as possible" do
                proposal.propose

                expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb", "/dev/sdc")
              end
            end
          end
        end

        # NOTE: this scenario, multidisk_first + allocate_volume_mode :auto, is
        # a kind of "fallback" to the behavior of the initial proposal before
        # changes introduced in https://github.com/yast/yast-storage-ng/pull/783
        context "with allocate_volume_mode set to :auto" do
          let(:allocate_mode) { :auto }

          context "using lvm" do
            let(:lvm) { true }

            before do
              sda.size = 5.GiB
              sdb.size = 15.GiB
              sdc.size = 20.GiB
            end

            context "with separated volume groups" do
              let(:separate_vgs) { true }

              # TODO: FIXME: this scenario is failing with
              # Y2Storage::NoDiskSpaceError because a problem assigning space
              # automatically for multiple LVM VGs. It seems that, for some
              # reason, one of them is "eating" all the avaible space.
              xit "spreads the proposal as much as possible" do
                proposal.propose

                expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb", "/dev/sdc")
              end
            end

            context "without separated volume groups" do
              let(:separate_vgs) { false }

              it "only use necessary devices" do
                proposal.propose

                expect(used_devices).to contain_exactly("/dev/sdb", "/dev/sdc")
              end
            end
          end

          context "not using lvm" do
            let(:lvm) { false }

            context "with separated volume groups" do
              let(:separate_vgs) { true }

              context "having enough space for a full proposal in an individual device" do
                before do
                  sda.size = 10.GiB
                  sdb.size = 100.GiB
                  sdc.size = 30.GiB
                end

                it "makes the full proposal using a single device" do
                  proposal.propose

                  expect(used_devices).to contain_exactly("/dev/sdb")
                end
              end

              context "having enough space for an adjusted proposal in an individual device" do
                before do
                  sda.size = 25.GiB
                  sdb.size = 30.GiB
                  sdc.size = 35.GiB
                end

                it "makes the full proposal" do
                  proposal.propose

                  expect(proposed_vg_names).to include("vg-pgsql")
                end

                it "uses multiple disks" do
                  proposal.propose

                  expect(used_devices.count).to be > 1
                end
              end

              context "only having enough space for an adjusted proposal" do
                before do
                  sda.size = 11.GiB
                  sdb.size = 11.GiB
                  sdc.size = 11.GiB
                end

                it "makes the adjusted proposal" do
                  proposal.propose

                  expect(proposed_vg_names).to_not include("vg-pgsql")
                end

                it "uses multiple disks" do
                  proposal.propose

                  expect(used_devices.count).to be > 1
                end
              end
            end

            context "without separated volume groups" do
              let(:separate_vgs) { false }

              context "having enough space for a full proposal in an individual device" do
                before do
                  sda.size = 10.GiB
                  sdb.size = 100.GiB
                  sdc.size = 30.GiB
                end

                it "makes the full proposal using a single device" do
                  proposal.propose

                  expect(used_devices).to contain_exactly("/dev/sdb")
                end
              end

              context "having enough space for an adjusted proposal in an individual device" do
                before do
                  sda.size = 25.GiB
                  sdb.size = 30.GiB
                  sdc.size = 35.GiB
                end

                it "makes the full proposal" do
                  proposal.propose

                  expect(proposal.planned_devices.map(&:mount_point)).to include("/var/lib/pgsql")
                end

                it "uses multiple disks" do
                  proposal.propose

                  expect(used_devices.count).to be > 1
                end
              end

              context "only having enough space for an adjusted proposal" do
                before do
                  sda.size = 11.GiB
                  sdb.size = 11.GiB
                  sdc.size = 11.GiB
                end

                it "makes the adjusted proposal" do
                  proposal.propose

                  expect(proposal.planned_devices.map(&:mount_point)).to_not include("/var/lib/pgsql")
                end

                it "uses multiple disks" do
                  proposal.propose

                  expect(used_devices.count).to be > 1
                end
              end
            end
          end
        end
      end

      context "and a proposal is not possible with any individual device" do
        before do
          sdb.size = 15.GiB
          medium.size = 12.GiB
          small.size = 3.GiB
        end

        let(:swap_optional) { false }

        shared_examples "proposal in three devices" do
          it "allocates the root device in the biggest device" do
            proposal.propose

            expect(disk_for("/").name).to eq "/dev/sdb"
          end

          context "and swap is optional" do
            let(:swap_optional) { true }

            it "uses all the devices to make the proposal" do
              proposal.propose

              expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb", "/dev/sdc")
            end

            it "allocates the swap partition in a separate device" do
              proposal.propose

              expect(disk_for("swap").name).to eq small.name
            end
          end

          context "and swap is mandatory" do
            let(:swap_optional) { false }

            it "uses all the devices to make the proposal" do
              proposal.propose

              expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb", "/dev/sdc")
            end

            it "allocates the swap partition in a separate device" do
              proposal.propose

              expect(disk_for("swap").name).to eq small.name
            end
          end
        end

        context "with allocate_volume_mode set to :auto" do
          let(:allocate_mode) { :auto }

          context "and the sizes of the disks in the same order than the volumes sizes" do
            let(:medium) { sda }
            let(:small) { sdc }

            include_examples "proposal in three devices"
          end

          context "and the sizes of the disks in different order than the volumes sizes" do
            let(:medium) { sdc }
            let(:small) { sda }

            include_examples "proposal in three devices"
          end
        end

        context "with allocate_volume_mode set to :device" do
          let(:allocate_mode) { :device }

          context "and the sizes of the disks in the same order than the volumes sizes" do
            let(:medium) { sda }
            let(:small) { sdc }

            include_examples "proposal in three devices"
          end

          context "and the sizes of the disks in different order than the volumes sizes" do
            let(:medium) { sdc }
            let(:small) { sda }

            include_examples "proposal in three devices"
          end
        end
      end
    end

    context "when some candidate devices are given" do
      include_context "candidate devices"

      let(:candidate_devices) { ["/dev/sda", "/dev/sdb"] }

      let(:control_file_content) { ng_partitioning_section }

      let(:sda_usb) { true }

      shared_examples "proposal in two devices" do
        it "uses the biggest candidate device to make the proposal" do
          proposal.propose

          expect(disk_for("/").name).to eq "/dev/sda"
        end

        context "and a proposal is not possible with any individual candidate device" do
          before do
            sda.size = 12.GiB
            sdb.size = 15.GiB
            sdc.size = 3.GiB
          end

          it "uses all the candidate devices to make a proposal" do
            proposal.propose

            expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb")
          end
        end
      end

      context "with allocate_volume_mode set to :auto" do
        let(:allocate_mode) { :auto }

        include_examples "proposal in two devices"
      end

      context "with allocate_volume_mode set to :device" do
        let(:allocate_mode) { :device }

        include_examples "proposal in two devices"
      end
    end

    context "when a proposal is not possible with the current settings" do
      include_context "candidate devices"

      let(:candidate_devices) { ["/dev/sda"] }

      let(:control_file_content) { ng_partitioning_section }

      before do
        sda.size = 18.5.GiB
      end

      it "makes the proposal by disabling properties before moving to another candidate device" do
        proposal.propose

        partitions = proposal.devices.partitions
        mount_points = partitions.map(&:filesystem_mountpoint).compact

        expect(used_devices).to contain_exactly("/dev/sda")
        expect(mount_points).to_not include("swap")
      end
    end

    # Test, at hight level, that settings are reset between candidates
    #
    # Related to bsc#113092, settings must be **correctly** reset after moving to another (group
    # of) candidate device(s). To check that, the first candidate will be small enough to make not
    # possible the proposal on it even **after adjust the initial settings**, expecting to have a
    # valid proposal **with original settings** in the second candidate.
    context "when a proposal is not possible for a candidate even after adjust the settings" do
      include_context "candidate devices"

      let(:candidate_devices) { ["/dev/sda", "/dev/sdb"] }

      let(:control_file_content) { ng_partitioning_section }

      before do
        sda.size = 2.GiB
      end

      it "resets the settings before attempting a new proposal with next candidate" do
        proposal.propose

        partitions = proposal.devices.partitions
        mount_points = partitions.map(&:filesystem_mountpoint).compact

        expect(used_devices).to contain_exactly("/dev/sdb")

        # having expected mount points means that settings were reset properly, since in the
        # previous attempts swap and separated home should be deleted
        expect(mount_points).to include("swap", "/home", "/")
      end
    end

    context "when a proposal is not possible" do
      include_context "candidate devices"

      let(:candidate_devices) { ["/dev/sda"] }

      let(:control_file_content) { ng_partitioning_section }

      before do
        # root requires at least 8 GiB and home 10 GiB
        sda.size = 10.GiB
      end

      it "raises an error" do
        expect { proposal.propose }.to raise_error(Y2Storage::Error)
      end
    end

    # This context is here to add a couple of regression tests, see below
    context "with :device as allocate mode and :all for the delete modes" do
      include_context "candidate devices"

      let(:control_file_content) do
        {
          "partitioning" => {
            "proposal" => {
              "allocate_volume_mode" => :device,
              "windows_delete_mode"  => :all,
              "linux_delete_mode"    => :all,
              "other_delete_mode"    => :all
            },
            "volumes"  => volumes_spec
          }
        }
      end

      let(:volumes_spec) do
        [
          {
            "mount_point"           => "/",
            "fs_type"               => "ext4",
            "desired_size"          => "900GiB",
            "min_size"              => "900GiB",
            "proposed_configurable" => false
          },
          {
            "mount_point"           => "/var/one",
            "fs_type"               => "ext4",
            "desired_size"          => second_volume_size,
            "min_size"              => second_volume_size,
            "proposed_configurable" => false
          },
          {
            "mount_point"           => "/var/two",
            "fs_type"               => "ext4",
            "desired_size"          => "900GiB",
            "min_size"              => "900GiB",
            "proposed_configurable" => true,
            "disable_order"         => "1"
          }
        ]
      end

      before do
        # Ensure all the disks contain partitions, so we can check whether they
        # are deleted
        create_next_partition(sda)
        create_next_partition(sdb)
        create_next_partition(sdc)
      end

      context "when there are mandatory volumes that don't fit in the disks" do
        let(:second_volume_size) { "500GiB" }

        # Regression test: this used to produce an infinite loop because the SpaceMaker
        # object was reset in #reset_settings instead of in #try_with_each_target_size.
        # As a consequence, it contained an outdated list of candidate disks and was
        # unsuccessfully trying to delete the same partition over and over.
        it "raises an error" do
          expect { proposal.propose }.to raise_error(Y2Storage::Error)
        end
      end

      # Regression test: this used to apply the xxx_delete_mode :all to the wrong
      # disk(s) because @clean_graph was not reset on every attempt
      context "when a proposal is possible after switching to another disk" do
        let(:sda_usb) { true }
        let(:second_volume_size) { "20GiB" }

        it "wipes all partitions from the used disks" do
          sda_partitions = sda.partitions.map(&:sid)

          proposal.propose
          # Let's ensure sda was used, otherwise the subsequent check makes no sense
          expect(used_devices).to contain_exactly("/dev/sda")

          partitions_after = proposal.devices.partitions.map(&:sid)
          expect(partitions_after).to_not include(*sda_partitions)
        end

        it "does not wipe disks that are not used" do
          sdb_partitions = sdb.partitions.map(&:sid)
          sdc_partitions = sdc.partitions.map(&:sid)

          proposal.propose
          # Let's ensure only sda was used, otherwise the subsequent checks
          # would not make sense
          expect(used_devices).to contain_exactly("/dev/sda")

          partitions_after = proposal.devices.partitions.map(&:sid)
          expect(partitions_after).to include(*sdb_partitions)
          expect(partitions_after).to include(*sdc_partitions)
        end
      end
    end
  end
end
