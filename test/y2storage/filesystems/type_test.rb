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

require_relative "../spec_helper"
require "y2storage"

describe Y2Storage::Filesystems::Type do
  describe "#to_human_string" do
    it "returns the description of the type" do
      expect(Y2Storage::Filesystems::Type::HFSPLUS.to_human_string).to eq "MacHFS+"
    end

    it "returns the internal name (#to_s) for types with no description" do
      expect(Y2Storage::Filesystems::Type::TMPFS.to_human_string).to eq "tmpfs"
    end
  end
end
