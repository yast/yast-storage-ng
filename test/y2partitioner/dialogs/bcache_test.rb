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

require_relative "../test_helper"

require "yast"
require "cwm/rspec"
require "y2storage"
require "y2partitioner/dialogs/bcache"

describe Y2Partitioner::Dialogs::Bcache do
  before { devicegraph_stub("bcache1.xml") }

  let(:suitable_backing) { fake_devicegraph.blk_devices }
  let(:suitable_caching) { fake_devicegraph.blk_devices + fake_devicegraph.bcache_csets }

  subject { described_class.new(suitable_backing, suitable_caching) }

  include_examples "CWM::Dialog"

  describe "#contents" do
    it "contains a widget for entering the backing device" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Dialogs::Bcache::BackingDevice)
      end
      expect(widget).to_not(be_nil, "Widget not found in '#{subject.contents.inspect}'")
    end

    it "contains a widget for entering the caching device" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Dialogs::Bcache::CachingDevice)
      end
      expect(widget).to_not(be_nil, "Widget not found in '#{subject.contents.inspect}'")
    end
  end

  describe "#caching_device" do
    it "returns selected caching device" do
      allow_any_instance_of(Y2Partitioner::Dialogs::Bcache::CachingDevice).to receive(:result)
        .and_return(suitable_caching.first)

      expect(subject.caching_device).to eq suitable_caching.first
    end
  end

  describe "#backing_device" do
    it "returns selected backing device" do
      allow_any_instance_of(Y2Partitioner::Dialogs::Bcache::BackingDevice).to receive(:result)
        .and_return(suitable_backing.first)

      expect(subject.backing_device).to eq suitable_backing.first
    end
  end

  describe Y2Partitioner::Dialogs::Bcache::BackingDevice do
    subject { described_class.new(nil, suitable_backing, double(value: "test")) }

    before do
      allow(subject).to receive(:value).and_return(suitable_backing.first.sid.to_s)
    end

    include_examples "CWM::ComboBox"

    describe "#validate" do
      it "shows error popup if same device is used for backing and caching" do
        allow(subject).to receive(:value).and_return("test")

        expect(Yast2::Popup).to receive(:show)
        subject.validate
      end

      it "shows error popup if backing device is not selected" do
        allow(subject).to receive(:value).and_return("")

        expect(Yast2::Popup).to receive(:show)
        subject.validate
      end
    end

    describe "#result" do
      it "returns Y2Storage::BlkDevice according to selected name" do
        subject.store
        expect(subject.result).to eq suitable_backing.first
      end
    end
  end

  describe Y2Partitioner::Dialogs::Bcache::CachingDevice do
    subject { described_class.new(nil, suitable_caching) }

    before do
      allow(subject).to receive(:value).and_return(suitable_caching.last.sid.to_s)
    end

    include_examples "CWM::ComboBox"

    describe "#result" do
      it "returns Y2Storage::BlkDevice or Y2Storage::BcacheCset according to selected name" do
        subject.store
        expect(subject.result).to eq suitable_caching.last
      end
    end
  end
end
