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

describe Y2Storage::LvmVg do
  before do
    fake_scenario("complex-lvm-encrypt")
  end

  describe "#name" do
    it "returns string starting with /dev and containing vg_name" do
      subject = Y2Storage::StorageManager.instance.staging.lvm_vgs.first
      expect(subject.name).to start_with("/dev")
      expect(subject.name).to include(subject.vg_name)
    end
  end
end
