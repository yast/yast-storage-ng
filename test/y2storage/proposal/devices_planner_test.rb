#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016-2017] SUSE LLC
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
require_relative "#{TEST_PATH}/support/devices_planner_context"

require "storage"
require "y2storage"

describe Y2Storage::Proposal::DevicesPlanner do
  describe "#planned_devices" do
    using Y2Storage::Refinements::SizeCasts

    include_context "devices planner"

    subject { described_class.new(settings, devicegraph) }

    context "when the settings has legacy format" do
      it "uses legacy strategy to generate planned devices" do
        expect_any_instance_of(Y2Storage::Proposal::DevicesPlannerStrategies::Legacy)
          .to receive(:planned_devices)

        subject.planned_devices(:desired)
      end

      it "returns an array of planned devices" do
        expect(subject.planned_devices(:desired)).to be_a Array
        expect(subject.planned_devices(:desired)).to all(be_a(Y2Storage::Planned::Device))
      end
    end

    context "when the settings has ng format" do
      let(:control_file_content) do
        {
          "proposal" => {
            "lvm" => false
          },
          "volumes"  => []
        }
      end

      it "uses ng strategy to generate planned devices" do
        expect_any_instance_of(Y2Storage::Proposal::DevicesPlannerStrategies::Ng)
          .to receive(:planned_devices)

        subject.planned_devices(:desired)
      end

      it "returns an array of planned devices" do
        expect(subject.planned_devices(:desired)).to be_a Array
        expect(subject.planned_devices(:desired)).to all(be_a(Y2Storage::Planned::Device))
      end
    end
  end
end
