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
require "y2storage/autoinst_problems/problem"

describe Y2Storage::AutoinstProblems::Problem do
  subject(:problem) { described_class.new }

  describe "#message" do
    it "raise a NotImplementedError exception" do
      expect { problem.message }.to raise_error(NotImplementedError)
    end
  end

  describe "#severity" do
    it "returns :warn" do
      expect { problem.severity }.to raise_error(NotImplementedError)
    end
  end

  describe "#warn?" do
    before do
      allow(problem).to receive(:severity).and_return(severity)
    end

    context "when severity is :warn" do
      let(:severity) { :warn }

      it "returns true" do
        expect(problem).to be_warn
      end
    end

    context "when severity is not :warn" do
      let(:severity) { :fatal }

      it "returns false" do
        expect(problem).to_not be_warn
      end
    end
  end

  describe "#fatal?" do
    before do
      allow(problem).to receive(:severity).and_return(severity)
    end

    context "when severity is :fatal" do
      let(:severity) { :fatal }

      it "returns true" do
        expect(problem).to be_fatal
      end
    end

    context "when severity is not :fatal" do
      let(:severity) { :warn }

      it "returns false" do
        expect(problem).to_not be_fatal
      end
    end
  end
end
