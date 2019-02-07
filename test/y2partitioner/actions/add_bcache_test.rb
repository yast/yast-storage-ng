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

require "y2partitioner/device_graphs"
require "y2partitioner/actions/add_bcache"
require "y2partitioner/dialogs/bcache"

describe Y2Partitioner::Actions::AddBcache do
  subject { described_class.new }

  before do
    devicegraph_stub(scenario)

    allow_any_instance_of(Y2Partitioner::Dialogs::Bcache).to receive(:run)
      .and_return(dialog_result)

    allow_any_instance_of(Y2Partitioner::Dialogs::Bcache).to receive(:backing_device)
      .and_return(selected_backing)

    allow_any_instance_of(Y2Partitioner::Dialogs::Bcache).to receive(:caching_device)
      .and_return(selected_caching)

    allow_any_instance_of(Y2Partitioner::Dialogs::Bcache).to receive(:options)
      .and_return(selected_options)
  end

  let(:scenario) { "empty_disks.yml" }

  let(:dialog_result) { nil }

  let(:selected_backing) { fake_devicegraph.find_by_name("/dev/sda1") }

  let(:selected_caching) { nil }

  let(:selected_options) { { cache_mode: Y2Storage::CacheMode::WRITEBACK } }

  describe "#run" do
    let(:bcache) { fake_devicegraph.find_by_name("/dev/bcache0") }

    shared_examples "create new bcache" do
      it "creates a new bcache device" do
        expect(fake_devicegraph.bcaches).to be_empty

        subject.run

        expect(bcache).to_not be_nil
        expect(bcache.is?(:bcache)).to eq(true)
      end

      it "sets the selected cache mode" do
        subject.run

        expect(bcache.cache_mode).to eq(selected_options[:cache_mode])
      end
    end

    context "when the dialog is accepted" do
      let(:dialog_result) { :next }

      context "and a caching device was selected in the dialog" do
        let(:selected_caching) { fake_devicegraph.find_by_name("/dev/sdc") }

        include_examples "create new bcache"

        it "attaches the selected caching device" do
          subject.run

          expect(bcache.bcache_cset).to_not be_nil
          expect(bcache.bcache_cset.blk_devices.first).to eq(selected_caching)
        end

        it "returns :finish" do
          expect(subject.run).to eq :finish
        end
      end

      context "when no caching device was selected in the dialog" do
        let(:selected_caching) { nil }

        include_examples "create new bcache"

        it "does not attach a caching device" do
          subject.run

          expect(bcache.bcache_cset).to be_nil
        end

        it "returns :finish" do
          expect(subject.run).to eq :finish
        end
      end
    end

    context "when the dialog is discarded" do
      it "does not create a new bcache" do
        subject.run

        expect(fake_devicegraph.bcaches).to be_empty
      end

      it "returns :finish" do
        expect(subject.run).to eq :finish
      end
    end
  end
end
