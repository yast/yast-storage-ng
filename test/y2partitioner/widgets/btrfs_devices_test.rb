#!/usr/bin/env rspec
# encoding: utf-8

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

require_relative "../test_helper"

require "yast"
require "cwm/rspec"
require "y2partitioner/widgets/btrfs_devices"
require "y2partitioner/actions/controllers/btrfs_devices"

Yast.import "UI"

describe Y2Partitioner::Widgets::BtrfsDevices do
  before do
    devicegraph_stub(scenario)

    allow(Yast2::Popup).to receive(:show)
  end

  let(:controller) do
    Y2Partitioner::Actions::Controllers::BtrfsDevices.new
  end

  subject { described_class.new(controller) }

  let(:scenario) { "complex-lvm-encrypt.yml" }

  include_examples "CWM::CustomWidget"

  describe "#contents" do
    it "contains a widget for selecting the metadata raid level" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Widgets::BtrfsMetadataRaidLevel)
      end

      expect(widget).to_not be_nil
    end

    it "contains a widget for selecting the data raid level" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Widgets::BtrfsDataRaidLevel)
      end

      expect(widget).to_not be_nil
    end

    it "contains a widget for selecting the devices" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Widgets::BtrfsDevicesSelector)
      end
      expect(widget).to_not be_nil
    end
  end

  describe "#validate" do
    def dev(name)
      Y2Storage::BlkDevice.find_by_name(current_graph, name)
    end

    let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

    RSpec.shared_examples "do not validate" do
      it "returns false" do
        expect(subject.validate).to eq(false)
      end

      it "displays an error popup" do
        expect(Yast2::Popup).to receive(:show).with(anything, hash_including(headline: :error))

        subject.validate
      end
    end

    RSpec.shared_examples "validates" do
      it "returns true" do
        expect(subject.validate).to eq(true)
      end

      it "displays an error popup" do
        expect(Yast2::Popup).to_not receive(:show)

        subject.validate
      end
    end

    RSpec.shared_examples "raid levels validations" do
      context "DEFAULT" do
        let(:raid_level) { Y2Storage::BtrfsRaidLevel::DEFAULT }

        include_examples "validates"
      end

      context "DUP" do
        let(:raid_level) { Y2Storage::BtrfsRaidLevel::DUP }

        context "and there is only one device selected" do
          before do
            controller.add_device(dev("/dev/sda3"))
          end

          include_examples "validates"
        end

        context "but there is more than one device selected" do
          before do
            controller.add_device(dev("/dev/sda3"))
            controller.add_device(dev("/dev/sde3"))
          end

          include_examples "do not validate"
        end
      end

      context "RAID0" do
        let(:raid_level) { Y2Storage::BtrfsRaidLevel::RAID0 }

        context "and there is only one device selected" do
          before do
            controller.add_device(dev("/dev/sda3"))
          end

          include_examples "do not validate"
        end

        context "but there is more than one device selected" do
          before do
            controller.add_device(dev("/dev/sda3"))
            controller.add_device(dev("/dev/sde3"))
          end

          include_examples "validates"
        end
      end

      context "RAID1" do
        let(:raid_level) { Y2Storage::BtrfsRaidLevel::RAID1 }

        context "and there is only one device selected" do
          before do
            controller.add_device(dev("/dev/sda3"))
          end

          include_examples "do not validate"
        end

        context "but there is more than one device selected" do
          before do
            controller.add_device(dev("/dev/sda3"))
            controller.add_device(dev("/dev/sde3"))
          end

          include_examples "validates"
        end
      end

      context "RAID10" do
        let(:raid_level) { Y2Storage::BtrfsRaidLevel::RAID10 }

        context "and there are less than four devices selected" do
          before do
            controller.add_device(dev("/dev/sda3"))
            controller.add_device(dev("/dev/sde3"))
            controller.add_device(dev("/dev/sdf"))
          end

          include_examples "do not validate"
        end

        context "and there are at least four devices selected" do
          before do
            controller.add_device(dev("/dev/sda3"))
            controller.add_device(dev("/dev/sde3"))
            controller.add_device(dev("/dev/sdf"))
            controller.add_device(dev("/dev/vg1/lv1"))
          end

          include_examples "validates"
        end

        context "and there are more than four devices selected" do
          before do
            controller.add_device(dev("/dev/sda3"))
            controller.add_device(dev("/dev/sde3"))
            controller.add_device(dev("/dev/sdf"))
            controller.add_device(dev("/dev/vg1/lv1"))
            controller.add_device(dev("/dev/vg1/lv2"))
            controller.add_device(dev("/dev/vg0/lv2"))
          end

          include_examples "validates"
        end
      end
    end

    context "when changing the metadata raid level" do
      before do
        controller.metadata_raid_level = raid_level
      end

      include_examples "raid levels validations"
    end

    context "when changing data raid level" do
      before do
        controller.data_raid_level = raid_level
      end

      include_examples "raid levels validations"
    end
  end
end
