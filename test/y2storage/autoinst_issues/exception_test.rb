#!/usr/bin/env rspec
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
require "y2storage/autoinst_issues/exception"

describe Y2Storage::AutoinstIssues::Exception do
  subject(:issue) { described_class.new(error) }
  let(:error) { double("Error", message: "error message") }

  describe "#message" do
    it "includes relevant information" do
      expect(issue.message).to match(/A problem.*#{error.message}/)
    end
  end

  describe "#severity" do
    it "returns :fatal" do
      expect(issue.severity).to eq(:fatal)
    end
  end
end
