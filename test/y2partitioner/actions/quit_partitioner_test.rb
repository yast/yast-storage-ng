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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "y2partitioner/actions/quit_partitioner"

describe Y2Partitioner::Actions::QuitPartitioner do
  before do
    devicegraph_stub("mixed_disks")

    devicegraphs = Y2Partitioner::DeviceGraphs.instance
    allow(devicegraphs).to receive(:devices_edited?).and_return(devices_edited)

    allow(Y2Partitioner::DeviceGraphs).to receive(:instance).and_return(devicegraphs)
  end

  let(:devices_edited) { false }

  subject { described_class.new }

  describe "#run" do
    context "when no devices have been modified" do
      let(:devices_edited) { false }

      it "does not show a confirmation popup" do
        expect(Yast2::Popup).to_not receive(:show)

        subject.run
      end

      it "returns :quit" do
        expect(subject.run).to eq(:quit)
      end
    end

    context "when some devices have been modified" do
      let(:devices_edited) { true }

      before do
        allow(Yast2::Popup).to receive(:show).and_return(accept)
      end

      let(:accept) { nil }

      it "shows a confirmation popup" do
        expect(Yast2::Popup).to receive(:show).with(/modified some devices/, anything)

        subject.run
      end

      context "and the user accepts" do
        let(:accept) { :yes }

        it "returns :quit" do
          expect(subject.run).to eq(:quit)
        end
      end

      context "and the user does not accept" do
        let(:accept) { :no }

        it "returns nil" do
          expect(subject.run).to be_nil
        end
      end
    end
  end

  describe "#quit?" do
    context "when no devices have been modified" do
      let(:devices_edited) { false }

      it "returns true" do
        expect(subject.quit?).to eq(true)
      end
    end

    context "when some devices have been modified" do
      let(:devices_edited) { true }

      before do
        allow(Yast2::Popup).to receive(:show).and_return(accept)
      end

      context "and the user accepts to quit" do
        let(:accept) { :yes }

        it "returns true" do
          expect(subject.quit?).to eq(true)
        end
      end

      context "and the user does not accept to quit" do
        let(:accept) { :no }

        it "returns false" do
          expect(subject.quit?).to eq(false)
        end
      end
    end
  end
end
