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
require "y2storage"

describe Y2Storage::VolumeSpecificationsSet do
  using Y2Storage::Refinements::SizeCasts

  subject(:volumes_set) { described_class.new(volumes, type) }

  let(:proposed) { false }
  let(:home_device) { nil }
  let(:var_device) { nil }
  let(:home_vg_name) { nil }
  let(:var_vg_name) { nil }

  let(:home_volume) do
    instance_double("Y2Storage::VolumeSpecification",
      proposed?:        proposed,
      device:           home_device,
      separate_vg_name: home_vg_name)
  end

  let(:var_volume) do
    instance_double("Y2Storage::VolumeSpecification",
      proposed?:        false,
      device:           var_device,
      separate_vg_name: var_vg_name)
  end

  let(:volumes) { [home_volume, var_volume] }
  let(:type) { :lvm }

  describe "#proposed?" do
    context "when no volume is proposed" do
      it "returns false" do
        expect(volumes_set.proposed?).to eq(false)
      end
    end

    context "when any volume is proposed" do
      let(:proposed) { true }

      it "returns true" do
        expect(volumes_set.proposed?).to eq(true)
      end
    end
  end

  describe "#device" do
    context "when no volume has an associatted device" do
      it "returns nil" do
        expect(volumes_set.device).to be_nil
      end
    end

    context "when some volume has an associatted device" do
      let(:var_device) { "/path/to/some/device" }

      it "returns the device path" do
        expect(volumes_set.device).to eq("/path/to/some/device")
      end
    end

    context "when all volumes have an associatted device" do
      let(:home_device) { "/path/to/home/device" }
      let(:var_device) { "/path/to/some/device" }

      it "returns the first found" do
        expect(volumes_set.device).to eq("/path/to/home/device")
      end
    end
  end

  describe "#device=" do
    it "changes the device for all of its volumes" do
      expect(home_volume).to receive(:device=)
      expect(var_volume).to receive(:device=)

      volumes_set.device = "/dev/sda"
    end
  end

  describe "#vg_name" do
    context "when no volume has a separated vg name" do
      it "returns nil" do
        expect(volumes_set.vg_name).to be_nil
      end
    end

    context "when there are volumes with a separate vg name" do
      let(:home_vg_name) { "vg-home" }
      let(:var_vg_name) { "vg-var" }

      it "returns the first found" do
        # Note: actually, all volumes in a volume set must have the same vg-name
        expect(volumes_set.vg_name).to eq("vg-home")
      end
    end
  end

  describe "#push" do
    let(:other_volume) { double("Y2Storage::VolumeSpecification") }

    it "adds the given volume to the set" do
      expect { volumes_set.push(other_volume) }.to change { volumes_set.volumes.count }.by(1)
    end
  end
end
