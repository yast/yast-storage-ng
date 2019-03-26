#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018-2019] SUSE LLC
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
require "y2partitioner/actions/controllers/bcache"

describe Y2Partitioner::Dialogs::Bcache do
  before do
    devicegraph_stub("bcache1.xml")

    allow(Y2Partitioner::Actions::Controllers::Bcache).to receive(:new).and_return(controller)

    allow(controller).to receive(:bcache).and_return(bcache)
    allow(controller).to receive(:suitable_caching_devices).and_return(suitable_caching)
    allow(controller).to receive(:suitable_backing_devices).and_return(suitable_backing)
  end

  let(:controller) { instance_double(Y2Partitioner::Actions::Controllers::Bcache) }

  let(:bcache) { nil }
  let(:suitable_backing) { fake_devicegraph.blk_devices }
  let(:suitable_caching) { fake_devicegraph.blk_devices + fake_devicegraph.bcache_csets }

  subject { described_class.new(controller) }

  include_examples "CWM::Dialog"

  describe "#contents" do
    it "contains a widget for entering the backing device" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Dialogs::Bcache::BackingDeviceSelector)
      end
      expect(widget).to_not(be_nil, "Widget not found in '#{subject.contents.inspect}'")
    end

    it "contains a widget for entering the caching device" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Dialogs::Bcache::CachingDeviceSelector)
      end
      expect(widget).to_not(be_nil, "Widget not found in '#{subject.contents.inspect}'")
    end

    it "contains a widget for entering the cache mode" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Dialogs::Bcache::CacheModeSelector)
      end
      expect(widget).to_not(be_nil, "Widget not found in '#{subject.contents.inspect}'")
    end

  end

  describe "#caching_device" do
    it "returns selected caching device" do
      allow_any_instance_of(Y2Partitioner::Dialogs::Bcache::CachingDeviceSelector).to receive(:result)
        .and_return(suitable_caching.first)

      expect(subject.caching_device).to eq suitable_caching.first
    end
  end

  describe "#backing_device" do
    it "returns selected backing device" do
      allow_any_instance_of(Y2Partitioner::Dialogs::Bcache::BackingDeviceSelector).to receive(:result)
        .and_return(suitable_backing.first)

      expect(subject.backing_device).to eq suitable_backing.first
    end
  end

  describe "#options" do
    it "returns hash containing cache_mode" do
      allow_any_instance_of(Y2Partitioner::Dialogs::Bcache::CacheModeSelector).to receive(:result)
        .and_return(Y2Storage::CacheMode::WRITEAROUND)

      expect(subject.options[:cache_mode]).to eq Y2Storage::CacheMode::WRITEAROUND
    end
  end

  describe Y2Partitioner::Dialogs::Bcache::BackingDeviceSelector do
    before do
      allow(subject).to receive(:value).and_return(suitable_backing.first.sid.to_s)
    end

    subject { described_class.new(bcache, suitable_backing, double(value: caching_value)) }

    let(:bcache) { nil }

    let(:caching_value) { "test" }

    include_examples "CWM::ComboBox"

    describe "#init" do
      context "when a new bcache is being created" do
        let(:bcache) { nil }

        it "selects the first suitable backing device" do
          expect(subject).to receive(:value=).with(suitable_backing.first.sid.to_s)
            .and_call_original

          subject.init
        end
      end

      context "when the bcache already exists" do
        let(:bcache) { fake_devicegraph.find_by_name("/dev/bcache0") }

        it "selects its backing device" do
          expect(subject).to receive(:value=).with(bcache.backing_device.sid.to_s)
            .and_call_original

          subject.init
        end
      end
    end

    describe "#validate" do
      before do
        allow(subject).to receive(:value).and_return(value)

        allow(Yast2::Popup).to receive(:show)
      end

      context "when no backing device has been selected" do
        let(:value) { "" }

        it "raises an error" do
          expect { subject.validate }.to raise_error(RuntimeError)
        end
      end

      context "when a backing device has been selected" do
        let(:value) { "device" }

        context "and it is different to the selected caching device" do
          let(:caching_value) { "another_device" }

          it "does not show a popup" do
            expect(Yast2::Popup).to_not receive(:show)
              .with(/cannot be identical/, anything)

            subject.validate
          end

          it "returns true" do
            expect(subject.validate).to eq(true)
          end
        end

        context "and the same device was selected as caching device" do
          let(:caching_value) { "device" }

          it "shows an error popup" do
            expect(Yast2::Popup).to receive(:show)

            subject.validate
          end

          it "returns false" do
            expect(subject.validate).to eq(false)
          end
        end
      end
    end

    describe "#result" do
      it "returns Y2Storage::BlkDevice according to selected name" do
        subject.store
        expect(subject.result).to eq suitable_backing.first
      end
    end
  end

  describe Y2Partitioner::Dialogs::Bcache::CachingDeviceSelector do
    subject { described_class.new(bcache, suitable_caching) }

    before do
      allow(subject).to receive(:value).and_return(suitable_caching.last.sid.to_s)
    end

    let(:bcache) { nil }

    include_examples "CWM::ComboBox"

    describe "#init" do
      context "when a new bcache is being created" do
        let(:bcache) { nil }

        it "selects the first suitable caching device" do
          expect(subject).to receive(:value=).with(suitable_caching.first.sid.to_s)
            .and_call_original

          subject.init
        end
      end

      context "when the bcache already exists" do
        context "and the bcache has a caching set" do
          let(:bcache) { fake_devicegraph.find_by_name("/dev/bcache0") }

          it "selects its caching set" do
            expect(subject).to receive(:value=).with(bcache.bcache_cset.sid.to_s)
              .and_call_original

            subject.init
          end
        end

        context "and the bcache has no caching set" do
          before do
            vda1 = fake_devicegraph.find_by_name("/dev/vda1")
            vda1.create_bcache("/dev/bcache99")
          end

          let(:bcache) { fake_devicegraph.find_by_name("/dev/bcache99") }

          it "selects the first suitable caching device" do
            expect(subject).to receive(:value=).with(suitable_caching.first.sid.to_s)
              .and_call_original

            subject.init
          end
        end
      end
    end

    describe "#result" do
      it "returns Y2Storage::BlkDevice or Y2Storage::BcacheCset according to selected name" do
        subject.store
        expect(subject.result).to eq suitable_caching.last
      end
    end

    describe "#items" do
      it "includes an option to select none caching device" do
        expect(subject.items).to include(["", "Without caching"])
      end
    end
  end

  describe Y2Partitioner::Dialogs::Bcache::CacheModeSelector do
    subject { described_class.new(bcache) }

    let(:bcache) { nil }

    before do
      allow(subject).to receive(:value).and_return(:writeback)
    end

    include_examples "CWM::ComboBox"

    describe "#init" do
      context "when a new bcache is being created" do
        let(:bcache) { nil }

        it "selects writethrough mode" do
          expect(subject).to receive(:value=).with(Y2Storage::CacheMode::WRITETHROUGH.to_sym.to_s)
            .and_call_original

          subject.init
        end
      end

      context "when the bcache already exists" do
        let(:bcache) { fake_devicegraph.find_by_name("/dev/bcache0") }

        before do
          bcache.cache_mode = Y2Storage::CacheMode::WRITEBACK
        end

        it "selects its current cache mode" do
          expect(subject).to receive(:value=).with(Y2Storage::CacheMode::WRITEBACK.to_sym.to_s)
            .and_call_original

          subject.init
        end
      end
    end

    describe "#result" do
      it "returns CacheMode Symbol" do
        subject.store
        expect(subject.result).to eq Y2Storage::CacheMode::WRITEBACK
      end
    end
  end
end
