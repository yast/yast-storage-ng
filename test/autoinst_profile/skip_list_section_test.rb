# encoding: utf-8
#
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

describe Y2Storage::AutoinstProfile::SkipListSection do
  subject(:list) { described_class.new([rule1, rule2]) }

  let(:rule1) { instance_double(Y2Storage::AutoinstProfile::SkipRule, matches?: true, valid?: true) }
  let(:rule2) { instance_double(Y2Storage::AutoinstProfile::SkipRule, matches?: true, valid?: true) }
  let(:disk) { instance_double(Y2Storage::Disk) }

  describe ".from_profile" do
    let(:spec) do
      [
        { "skip_key" => "size_k", "skip_value" => "1024" },
        { "skip_key" => "device", "skip_value" => "/dev/sda1" }
      ]
    end

    it "creates a list with rules" do
      allow(Y2Storage::AutoinstProfile::SkipRule).to receive(:from_profile_rule)
        .and_return(rule1, rule2)
      list = Y2Storage::AutoinstProfile::SkipListSection.new_from_hashes(spec)
      expect(list.rules).to eq([rule1, rule2])
    end
  end

  describe "#matches?" do
    context "when some rule matches" do
      before do
        allow(rule1).to receive(:matches?).and_return(true)
      end

      it "returns true" do
        expect(rule2).to_not receive(:matches?)
        expect(list.matches?(disk)).to eq(true)
      end
    end

    context "when no rule matches" do
      before do
        allow(rule1).to receive(:matches?).and_return(false)
        allow(rule2).to receive(:matches?).and_return(false)
      end

      it "returns false" do
        expect(list.matches?(disk)).to eq(false)
      end
    end

    context "when some rule is not valid" do
      before do
        allow(rule1).to receive(:valid?).and_return(false)
        allow(rule1).to receive(:inspect).and_return("rule1")
      end

      it "ignores the not valid rule" do
        expect(rule1).to_not receive(:matches?)
        expect(list.log).to receive(:error).with(/Some skip rules were ignored: rule1/)
        expect(list.matches?(disk)).to eq(true)
      end
    end
  end
end
