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

RSpec.shared_examples "libstorage callbacks" do
  describe "#error" do
    it "displays the error to the user" do
      expect(Yast::Report).to receive(:ErrorAnyQuestion) do |_headline, message|
        expect(message).to include "the message"
        expect(message).to include "the what"
      end
      subject.error("the message", "the what")
    end

    it "asks the user whether to continue and returns the answer" do
      allow(Yast::Report).to receive(:ErrorAnyQuestion).and_return(false, false, true)
      expect(subject.error("", "yes?")).to eq false
      expect(subject.error("", "please")).to eq false
      expect(subject.error("", "pretty please")).to eq true
    end
  end
end
