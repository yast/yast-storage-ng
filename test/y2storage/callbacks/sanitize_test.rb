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
require "y2storage/callbacks/sanitize"

describe Y2Storage::Callbacks::Sanitize do
  subject(:callbacks) { described_class.new }

  let(:errors) { [error1, error2] }

  let(:error1) { "Error 1" }
  let(:error2) { "Error 2" }

  describe "#sanitize?" do
    it "displays the errors to the user" do
      expect(Yast::Report).to receive(:ErrorAnyQuestion) do |_headline, message|
        expect(message).to include(error1)
        expect(message).to include(error2)
      end
      subject.sanitize?(errors)
    end

    it "asks the user whether to continue and returns the answer" do
      allow(Yast::Report).to receive(:ErrorAnyQuestion).and_return(false, false, true)
      expect(subject.sanitize?(errors)).to eq(false)
      expect(subject.sanitize?(errors)).to eq(false)
      expect(subject.sanitize?(errors)).to eq(true)
    end

    it "returns true by default" do
      expect(Yast::Report).to receive(:ErrorAnyQuestion) do |*args|
        expect(args[4]).to eq(:focus_yes)
      end
      subject.sanitize?(errors)
    end
  end
end
