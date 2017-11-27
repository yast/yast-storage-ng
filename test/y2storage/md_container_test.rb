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

require_relative "spec_helper"
require "y2storage"

describe Y2Storage::MdContainer do
  before do
    fake_scenario("mixed_disks")
  end

  let(:devicegraph) { fake_devicegraph }

  subject { described_class.create(devicegraph, "/dev/md/imsm0") }

  describe ".all" do
    before do
      Y2Storage::MdContainer.create(devicegraph, "/dev/md/imsm0")
      Y2Storage::MdContainer.create(devicegraph, "/dev/md/imsm1")
      Y2Storage::Md.create(devicegraph, "/dev/md2")
    end

    it "includes all MD containers" do
      expect(described_class.all(devicegraph).map(&:name))
        .to contain_exactly("/dev/md/imsm0", "/dev/md/imsm1")
    end
  end

  describe "#software_defined?" do
    it "returns false" do
      expect(subject.software_defined?).to eq(false)
    end
  end
end
