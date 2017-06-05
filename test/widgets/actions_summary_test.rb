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

require_relative "../spec_helper"
require "y2storage/widgets/actions_summary"

describe Y2Storage::Widgets::ActionsSummary do
  subject { described_class.new(id, actiongraph) }

  let(:id) { :summary }
  let(:actiongraph) { double(Y2Storage::Actiongraph, compound_actions: compound_actions) }
  let(:ca_delete_device) { instance_double(Y2Storage::CompoundAction) }
  let(:ca_create_device) { instance_double(Y2Storage::CompoundAction) }
  let(:ca_delete_subvol) { instance_double(Y2Storage::CompoundAction) }
  let(:ca_create_subvol) { instance_double(Y2Storage::CompoundAction) }

  before do
    allow(ca_delete_device).to receive(:delete?).and_return(true)
    allow(ca_delete_device).to receive(:device_is?).with(:btrfs_subvolume).and_return(false)
    allow(ca_delete_device).to receive(:sentence).and_return("delete device action")

    allow(ca_create_device).to receive(:delete?).and_return(false)
    allow(ca_create_device).to receive(:device_is?).with(:btrfs_subvolume).and_return(false)
    allow(ca_create_device).to receive(:sentence).and_return("create device action")

    allow(ca_delete_subvol).to receive(:delete?).and_return(true)
    allow(ca_delete_subvol).to receive(:device_is?).with(:btrfs_subvolume).and_return(true)
    allow(ca_delete_subvol).to receive(:sentence).and_return("delete subvolume action")

    allow(ca_create_subvol).to receive(:delete?).and_return(false)
    allow(ca_create_subvol).to receive(:device_is?).with(:btrfs_subvolume).and_return(true)
    allow(ca_create_subvol).to receive(:sentence).and_return("create subvolume action")
  end

  describe "#content" do
    let(:compound_actions) { [ca_create_device, ca_delete_device] }
    let(:widget_content) { subject.content[1] }

    it "shows delete actions in bold" do
      expect(widget_content).to include "<b>delete device action</b>"
    end

    it "shows delete actions first" do
      expect(widget_content)
        .to include "<ul><li><b>delete device action</b></li><li>create device action</li>"
    end

    context "when there are not subvolume actions" do
      let(:compound_actions) { [ca_create_device, ca_delete_device] }

      it "does not show subvolumes line" do
        expect(widget_content).not_to include "see details"
      end
    end

    context "when there are subvolume actions" do
      let(:compound_actions) { [ca_create_device, ca_create_subvol, ca_delete_device, ca_delete_subvol] }

      it "shows collapsed subvolumes by default" do
        expect(widget_content).to include "see details"
        expect(widget_content).not_to include "delete subvolume"
        expect(widget_content).not_to include "create subvolume"
      end

      context "when subvolume actions are expanded" do
        before do
          allow(subject).to receive(:collapsed_subvolumes?).and_return(false)
        end

        it "shows delete subvolume actions first" do
          expect(widget_content)
            .to include "<li><b>delete subvolume action</b></li><li>create subvolume action</li>"
        end
      end
    end
  end

  describe "#handle" do
    let(:compound_actions) { [ca_create_device, ca_create_subvol, ca_delete_device, ca_delete_subvol] }

    context "when input is unknown" do
      let(:input) { :unknown }

      it "does not update the content" do
        expect(Yast::UI).not_to receive(:ChangeWidget).with(id, anything, anything)
        subject.handle(input)
      end
    end

    context "when input is 'subvolumes'" do
      let(:input) { :subvolumes }

      it "toggles subvolumes list" do
        expect(subject).to receive(:toggle_subvolumes)
        subject.handle(input)
      end

      it "updates the content" do
        expect(Yast::UI).to receive(:ChangeWidget).with(id, anything, anything)
        subject.handle(input)
      end
    end
  end
end
