#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/actions/edit_bcache"

describe Y2Partitioner::Actions::EditBcache do
  subject { described_class.new(device) }

  before do
    devicegraph_stub(scenario)

    allow_any_instance_of(Y2Partitioner::Dialogs::Bcache).to receive(:run)
      .and_return(dialog_result)

    allow_any_instance_of(Y2Partitioner::Dialogs::Bcache).to receive(:caching_device)
      .and_return(selected_caching)

    allow_any_instance_of(Y2Partitioner::Dialogs::Bcache).to receive(:options)
      .and_return(selected_options)
  end

  let(:dialog_result) { nil }

  let(:selected_caching) { nil }

  let(:selected_options) { { cache_mode: Y2Storage::CacheMode::WRITEBACK } }

  let(:device) { device_graph.find_by_name(device_name) }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  describe "#run" do
    before do
      allow(Yast2::Popup).to receive(:show)
    end

    shared_examples "not edit device" do
      it "does not modify the caching device" do
        bcache_cset = device.bcache_cset

        subject.run

        expect(device.bcache_cset).to eq(bcache_cset)
      end

      it "does not modify the cache mode" do
        cache_mode = device.cache_mode

        subject.run

        expect(device.cache_mode).to eq(cache_mode)
      end
    end

    shared_examples "not edit action" do
      it "does not open a dialog to edit a bcache device" do
        expect(Y2Partitioner::Dialogs::Bcache).to_not receive(:new)

        subject.run
      end

      include_examples "not edit device"

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    shared_examples "edit action" do
      it "does not show an error popup" do
        expect(Yast2::Popup).to_not receive(:show)

        subject.run
      end

      it "opens a dialog to edit the bcache device" do
        expect(Y2Partitioner::Dialogs::Bcache).to receive(:new).and_call_original

        subject.run
      end

      context "when the dialog is accepted" do
        let(:dialog_result) { :next }

        context "and a caching device was selected in the dialog" do
          before do
            # Only to ensure the pre-condition is fulfilled
            expect(selected_caching).to_not be_nil
          end

          it "attaches the selected caching device" do
            subject.run

            expect(device.bcache_cset).to_not be_nil
            expect(device.bcache_cset.blk_devices.first).to eq(selected_caching)
          end

          it "sets the selected cache mode" do
            subject.run

            expect(device.cache_mode).to eq(selected_options[:cache_mode])
          end

          it "returns :finish" do
            expect(subject.run).to eq :finish
          end
        end

        context "when no caching device was selected in the dialog" do
          let(:selected_caching) { nil }

          it "does not attach a caching device" do
            subject.run

            expect(device.bcache_cset).to be_nil
          end

          it "sets the selected cache mode" do
            subject.run

            expect(device.cache_mode).to eq(selected_options[:cache_mode])
          end

          it "returns :finish" do
            expect(subject.run).to eq :finish
          end
        end
      end

      context "when the dialog is discarded" do
        let(:dialog_result) { :back }

        include_examples "not edit device"

        it "returns :finish" do
          expect(subject.run).to eq :finish
        end
      end
    end

    context "when the device is a flash-only bcache" do
      let(:scenario) { "bcache2.xml" }

      let(:device_name) { "/dev/bcache1" }

      before do
        # Only to ensure the pre-condition is fulfilled
        expect(device.flash_only?).to eq(true)
      end

      it "shows an error message" do
        expect(Yast2::Popup).to receive(:show).with(/is a flash-only/, headline: :error)

        subject.run
      end

      include_examples "not edit action"
    end

    context "when the bcache already exists on disk" do
      let(:system_device) { Y2Partitioner::DeviceGraphs.instance.system.find_device(device.sid) }

      let(:scenario) { "bcache1.xml" }

      let(:device_name) { "/dev/bcache1" }

      # Preparing a value for examples that need it (see shared examples "edit bcache")
      let(:selected_caching) { device_graph.find_by_name("/dev/vda2") }

      before do
        # Only to ensure the pre-condition is fulfilled
        expect(system_device).to_not be_nil
      end

      context "and it had a caching set on disk" do
        before do
          # Only to ensure the pre-condition is fulfilled
          expect(system_device.bcache_cset).to_not be_nil
        end

        it "shows an error message" do
          expect(Yast2::Popup).to receive(:show).with(/already created/, headline: :error)

          subject.run
        end

        include_examples "not edit action"
      end

      context "and it did not have a caching set on disk" do
        before do
          system_device.remove_bcache_cset
        end

        context "and it currently has no caching set either" do
          before do
            device.remove_bcache_cset
          end

          include_examples "edit action"
        end

        context "and it currently has a caching set" do
          before do
            # Only to ensure the pre-condition is fulfilled
            expect(device.bcache_cset).to_not be_nil
          end

          include_examples "edit action"
        end
      end
    end

    context "when the bcache does not exist on disk" do
      let(:scenario) { "bcache1.xml" }

      before do
        vda1 = device_graph.find_by_name("/dev/vda1")

        vda1.create_bcache(device_name)
      end

      let(:device_name) { "/dev/bcache99" }

      # Preparing a value for examples that need it (see shared examples "edit bcache")
      let(:selected_caching) { device_graph.find_by_name("/dev/vda2") }

      include_examples "edit action"
    end
  end
end
