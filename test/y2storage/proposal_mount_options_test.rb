#!/usr/bin/env rspec
# Copyright (c) [2021] SUSE LLC
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

describe Y2Storage::GuidedProposal do
  using Y2Storage::Refinements::SizeCasts
  let(:architecture) { :x86 }

  include_context "proposal"
  let(:separate_home) { true }

  let(:scenario) { "empty_disks" }
  before { settings.candidate_devices = ["/dev/sdb", "/dev/sdc"] }

  let(:control_file_content) do
    { "partitioning" => { "proposal" => {}, "volumes" => volumes } }
  end

  let(:volumes) { [root_vol, home_vol] }
  let(:root_vol) { { "mount_point" => "/", "fs_type" => root_fstype, "desired_size" => "390 GiB" } }
  let(:home_vol) { { "mount_point" => "/home", "fs_type" => home_fstype, "desired_size" => "300 GiB" } }

  let(:root_fstype) { "btrfs" }
  let(:home_fstype) { "ext3" }

  describe "#propose" do
    subject(:proposal) { described_class.new(settings:) }

    context "locating a filesystem in a local disk" do
      let(:blk_device) { proposal.devices.find_by_name(dev_name) }
      let(:mountable) { blk_device.filesystem }

      context "for a Btrfs file-system" do
        let(:dev_name) { "/dev/sdb2" }

        it "sets #mount_options to an empty array" do
          proposal.propose
          expect(mountable.mount_options).to be_empty
        end
      end

      context "for a Btrfs subvolume" do
        let(:dev_name) { "/dev/sdb2" }
        let(:mountable) { blk_device.filesystem.btrfs_subvolumes.last }

        it "sets #mount_options to an array containing only the subvol option" do
          proposal.propose
          options = mountable.mount_options
          expect(options.size).to eq 1
          expect(options.first).to match(/^subvol=/)
        end
      end

      context "for an Ext3 file-system " do
        let(:dev_name) { "/dev/sdc1" }

        it "sets #mount_options to an array containing only the data option" do
          proposal.propose
          expect(mountable.mount_options).to eq ["data=ordered"]
        end
      end
    end

    context "locating a filesystem in a network disk" do
      let(:blk_device) { proposal.devices.find_by_name(dev_name) }
      let(:mountable) { blk_device.filesystem }

      before do
        allow_any_instance_of(Y2Storage::DataTransport).to receive(:network?).and_return true
      end

      context "for the root filesystem" do
        let(:dev_name) { "/dev/sdb2" }

        context "if it is a Btrfs file-system" do
          let(:root_fstype) { "btrfs" }

          it "sets #mount_options to an empty array" do
            proposal.propose
            expect(mountable.mount_options).to be_empty
          end
        end

        context "for a Btrfs subvolume" do
          let(:root_fstype) { "btrfs" }
          let(:mountable) { blk_device.filesystem.btrfs_subvolumes.last }

          it "sets #mount_options to an array containing only the subvol option" do
            proposal.propose
            options = mountable.mount_options
            expect(options.size).to eq 1
            expect(options.first).to match(/^subvol=/)
          end
        end

        context "for an Ext3 file-system " do
          let(:root_fstype) { "ext3" }

          it "sets #mount_options to an empty array" do
            proposal.propose
            expect(mountable.mount_options).to be_empty
          end
        end
      end

      context "for a non-root filesystem" do
        let(:dev_name) { "/dev/sdc1" }

        before do
          allow_any_instance_of(Y2Storage::Disk).to receive(:hwinfo).and_return(hwinfo)
        end

        let(:hwinfo) { Y2Storage::HWInfoDisk.new }

        context "for a Btrfs file-system" do
          let(:home_fstype) { "btrfs" }

          context "if the disk uses a driver that depends on a systemd service" do
            let(:hwinfo) { Y2Storage::HWInfoDisk.new(driver: ["fcoe"]) }

            it "sets #mount_options to an array containing only '_netdev'" do
              proposal.propose
              expect(mountable.mount_options).to eq ["_netdev"]
            end
          end

          context "if the disk driver does not depend on any systemd service" do
            it "sets #mount_options to an empty array" do
              proposal.propose
              expect(mountable.mount_options).to be_empty
            end
          end
        end

        context "for an Ext3 file-system " do
          let(:home_fstype) { "ext3" }

          context "if the disk uses a driver that depends on a systemd service" do
            let(:hwinfo) { Y2Storage::HWInfoDisk.new(driver: ["iscsi-tcp"]) }

            it "sets #mount_options to an array containing the 'data' and '_netdev' options" do
              proposal.propose
              expect(mountable.mount_options).to contain_exactly("data=ordered", "_netdev")
            end
          end

          context "if the disk driver does not depend on any systemd service" do
            let(:hwinfo) { Y2Storage::HWInfoDisk.new(driver: ["qla4xxx"]) }

            it "sets #mount_options to an array containing only the data option" do
              proposal.propose
              expect(mountable.mount_options).to eq ["data=ordered"]
            end
          end
        end
      end
    end
  end
end
