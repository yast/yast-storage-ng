#!/usr/bin/env rspec
# encoding: utf-8

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

describe Y2Storage::Filesystems::MountByType do
  describe "#to_human_string" do
    it "returns a translated string" do
      described_class.all.each do |mount_by|
        expect(mount_by.to_human_string).to be_a(String)
      end
    end

    it "returns the internal name (#to_s) for types with no name" do
      allow(described_class::LABEL).to receive(:name).and_return(nil)
      expect(described_class::LABEL.to_human_string).to eq("label")
    end
  end
end
