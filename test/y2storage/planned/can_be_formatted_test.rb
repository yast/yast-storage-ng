#!/usr/bin/env rspec
# Copyright (c) [2018] SUSE LLC
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

require_relative "../spec_helper"
require "y2storage"

describe Y2Storage::Planned::CanBeFormatted do
  using Y2Storage::Refinements::SizeCasts

  # Dummy class to test the mixing
  class FormattableDevice < Y2Storage::Planned::Device
    include Y2Storage::Planned::CanBeMounted
    include Y2Storage::Planned::CanBeFormatted

    attr_accessor :reuse

    def initialize
      super
      initialize_can_be_formatted
      initialize_can_be_mounted
    end

    def reuse!(devicegraph)
      dev = Y2Storage::BlkDevice.find_by_name(devicegraph, reuse)
      reuse_device!(dev)
    end
  end

  subject(:planned) { FormattableDevice.new }
  let(:blk_device) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, device_name) }
  let(:mount_by) { Y2Storage::Filesystems::MountByType::DEVICE }
  let(:mount_point) { "/" }

  before do
    fake_scenario("windows-linux-free-pc")
  end

  describe "#format!" do
    let(:filesystem_type) { Y2Storage::Filesystems::Type::BTRFS }
    let(:device_name) { "/dev/sda2" }

    before do
      planned.filesystem_type = filesystem_type
      planned.mount_point = mount_point
      planned.mount_by = mount_by
    end

    it "creates a filesystem of the given type" do
      planned.format!(blk_device)
      expect(blk_device.filesystem.type).to eq(filesystem_type)
    end

    it "sets the mount_by option" do
      planned.format!(blk_device)
      expect(blk_device.filesystem.mount_by).to eq(mount_by)
    end

    context "when filesystem type is not defined" do
      let(:filesystem_type) { nil }

      it "does not format the device" do
        planned.format!(blk_device)
        expect(blk_device.filesystem.type).to eq(Y2Storage::Filesystems::Type::SWAP)
      end
    end

    context "when filesystem is set as read-only" do
      before do
        planned.read_only = true
      end

      it "sets the 'ro' option" do
        planned.format!(blk_device)
        expect(blk_device.filesystem.mount_options).to include("ro")
      end

      context "but fstab options include the 'rw' flag" do
        before do
          planned.fstab_options = ["rw"]
        end

        it "does not set the 'ro' option" do
          planned.format!(blk_device)
          expect(blk_device.filesystem.mount_options).to_not include("ro")
        end
      end
    end
  end

  describe "#reuse_device!" do
    let(:device_name) { "/dev/sda3" }
    let(:filesystem_type) { Y2Storage::Filesystems::Type::BTRFS }

    before do
      planned.reuse = device_name
    end

    context "when it should be formatted" do
      before do
        planned.reformat = true
        planned.filesystem_type = filesystem_type
      end

      it "formats the device" do
        expect(planned).to receive(:format!).with(blk_device)
        planned.reuse!(fake_devicegraph)
      end
    end

    context "when it should not be formatted" do
      before do
        planned.reformat = false
        planned.mount_point = "/old"
        planned.mount_by = mount_by
        allow(planned).to receive(:final_device!).and_return(blk_device)
      end

      context "and a mount point has been set" do
        it "sets the mount point" do
          planned.reuse!(fake_devicegraph)
          expect(blk_device.filesystem.mount_point.path).to eq("/old")
        end

        context "and a mount_by option is set" do
          it "sets the mount_by option" do
            planned.reuse!(fake_devicegraph)
            expect(blk_device.filesystem.mount_by).to eq(mount_by)
          end
        end

        context "and a mount_by option has not been set" do
          let(:mount_by) { nil }

          it "does not change the mount_by option" do
            expect { planned.reuse!(fake_devicegraph) }
              .to_not change { blk_device.filesystem.mount_by }
          end
        end
      end

      context "and a mount point has not been set" do
        before do
          planned.mount_point = nil
        end

        it "does not change the mount point" do
          expect { planned.reuse!(fake_devicegraph) }
            .to_not change { blk_device.filesystem.mount_point.path }
        end

        it "does not change the mount_by option" do
          expect { planned.reuse!(fake_devicegraph) }
            .to_not change { blk_device.filesystem.mount_by }
        end
      end
    end
  end
end
