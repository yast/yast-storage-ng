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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/import_mount_points_button"

describe Y2Partitioner::Widgets::ImportMountPointsButton do
  before do
    devicegraph_stub("mixed_disks.yml")

    allow(Y2Partitioner::Actions::ImportMountPoints).to receive(:new).and_return(action)
    allow(action).to receive(:run).and_return(action_result)
  end

  let(:action) { Y2Partitioner::Actions::ImportMountPoints.new }

  let(:action_result) { :finish }

  subject { described_class.new }

  include_examples "CWM::PushButton"

  describe "#handle" do
    it "performs the action for importing mount points" do
      expect(action).to receive(:run)

      subject.handle
    end

    context "when the action finishes correctly" do
      let(:action_result) { :finish }

      it "returns :redraw" do
        expect(subject.handle).to eq(:redraw)
      end
    end

    context "when theh action does not finish correctly" do
      let(:action_result) { :abort }

      it "returns nil" do
        expect(subject.handle).to be_nil
      end
    end
  end
end
