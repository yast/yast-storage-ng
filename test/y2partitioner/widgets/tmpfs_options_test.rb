#!/usr/bin/env rspec

# Copyright (c) [2020] SUSE LLC
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

require "cwm/rspec"
require "y2partitioner/widgets/tmpfs_options"
require "y2partitioner/actions/controllers"

describe Y2Partitioner::Widgets do
  before do
    devicegraph_stub(scenario)
    allow(Yast::UI).to receive(:ChangeWidget)
  end

  let(:scenario) { "tmpfs1-devicegraph.xml" }
  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:filesystem) { current_graph.tmp_filesystems.first }

  let(:controller) do
    Y2Partitioner::Actions::Controllers::Filesystem.new(filesystem, "")
  end

  describe Y2Partitioner::Widgets::TmpfsOptions do
    subject { described_class.new(controller, edit) }

    context "when editing an existing tmpfs" do
      let(:edit) { true }

      include_examples "CWM::CustomWidget"

      describe "#init" do
        it "disables the widget to modify the mount path" do
          expect(Yast::UI).to receive(:ChangeWidget)
            .with(Id("Y2Partitioner::Widgets::MountPoint"), :Enabled, false)

          subject.init
        end

        it "initializes the widget for the mount path with the correct value" do
          expect(Yast::UI).to receive(:ChangeWidget)
            .with(Id("Y2Partitioner::Widgets::MountPoint"), :Value, filesystem.mount_path)

          subject.init
        end
      end
    end

    context "when creating a new tmpfs" do
      let(:edit) { false }

      include_examples "CWM::CustomWidget"

      describe "#init" do
        it "does not disable the widget to modify the mount path" do
          expect(Yast::UI).to_not receive(:ChangeWidget)
            .with(Id("Y2Partitioner::Widgets::MountPoint"), :Enabled, false)

          subject.init
        end
      end

      describe "#validate" do
        it "silently returns true if the filesystem has a reasonable mount path" do
          expect(Yast::Popup).to_not receive(:Error)
          expect(subject.validate).to eq true
        end

        it "opens an error popup and returns false if filesystem is mounted at '/'" do
          filesystem.mount_path = "/"
          expect(Yast::Popup).to receive(:Error)
          expect(subject.validate).to eq false
        end
      end
    end
  end
end
