#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

require_relative "../../spec_helper"
require "y2storage/autoinst_issues/shrinked_planned_device"

describe Y2Storage::AutoinstIssues::ShrinkedPlannedDevice do
  using Y2Storage::Refinements::SizeCasts

  subject(:issue) { described_class.new(planned_device, real_device) }

  let(:planned_device) do
    instance_double(Y2Storage::Planned::Partition, mount_point: "/", min_size: 5.GiB)
  end

  let(:real_device) do
    instance_double(Y2Storage::Partition, name: "/dev/sda1", size: 2.GiB)
  end

  describe "#message" do
    it "returns a description of the issue" do
      expect(issue.message)
        .to include "Size for / (/dev/sda1) will be reduced from 5.00 GiB to 2.00 GiB"
    end
  end

  describe "#severity" do
    it "returns :warn" do
      expect(issue.severity).to eq(:warn)
    end
  end

  describe "#diff" do
    it "returns the size difference" do
      expect(issue.diff).to eq(3.GiB)
    end
  end
end
