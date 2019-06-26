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
require "y2storage/autoinst_issues/list"
require "y2storage/autoinst_issues/exception"
require "y2storage/autoinst_issues/invalid_value"

describe Y2Storage::AutoinstIssues::List do
  subject(:list) { described_class.new }

  let(:issue) { instance_double(Y2Storage::AutoinstIssues::Exception) }

  describe "#add" do
    it "adds a new issue to the list" do
      list.add(:exception, StandardError.new)
      expect(list.to_a).to all(be_an(Y2Storage::AutoinstIssues::Exception))
    end

    it "pass extra arguments to issue instance constructor" do
      expect(Y2Storage::AutoinstIssues::InvalidValue)
        .to receive(:new).with("/", :size, "value")
      list.add(:invalid_value, "/", :size, "value")
    end
  end

  describe "#to_a" do
    context "when list is empty" do
      it "returns an empty array" do
        expect(list.to_a).to eq([])
      end
    end

    context "when some issue was added" do
      before do
        2.times { list.add(:exception, StandardError.new) }
      end

      it "returns an array containing added issues" do
        expect(list.to_a).to all(be_a(Y2Storage::AutoinstIssues::Exception))
        expect(list.to_a.size).to eq(2)
      end
    end
  end

  describe "#empty?" do
    context "when list is empty" do
      it "returns true" do
        expect(list).to be_empty
      end
    end

    context "when some issue was added" do
      before { list.add(:exception, StandardError.new) }

      it "returns false" do
        expect(list).to_not be_empty
      end
    end
  end

  describe "#fatal?" do
    context "when contains some fatal error" do
      before { list.add(:missing_root) }

      it "returns true" do
        expect(list).to be_fatal
      end
    end

    context "when contains some fatal error" do
      before { list.add(:invalid_value, "/", :size, "value") }

      it "returns false" do
        expect(list).to_not be_fatal
      end
    end
  end
end
