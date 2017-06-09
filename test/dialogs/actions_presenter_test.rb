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
require "y2storage/dialogs/actions_presenter"

describe Y2Storage::ActionsPresenter do
  subject { described_class.new(actiongraph) }

  let(:actiongraph) { double(Y2Storage::Actiongraph, compound_actions: compound_actions) }
  let(:compound_actions) { [] }
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

  describe "#update_status" do
    before do
      allow(subject).to receive(:toggle_subvolumes_event).and_return("subvolumes")
    end

    context "when it receives a toggle subvolumes event" do
      it "toggles subvolumes" do
        expect(subject).to receive(:toggle_subvolumes)
        subject.update_status("subvolumes")
      end
    end

    context "when it receives other event" do
      it "does not toggle subvolumes" do
        expect(subject).not_to receive(:toggle_subvolumes)
        subject.update_status("other_event")
      end
    end
  end

  describe "#to_html" do
    let(:compound_actions) { [ca_create_device, ca_delete_device] }

    it "presents delete actions in bold" do
      expect(subject.to_html).to include "<b>delete device action</b>"
    end

    it "presents delete actions first" do
      expect(subject.to_html)
        .to include "<ul><li><b>delete device action</b></li><li>create device action</li>"
    end

    context "when there are not subvolume actions" do
      let(:compound_actions) { [ca_create_device, ca_delete_device] }

      it "does not include subvolumes line" do
        expect(subject.to_html).not_to include "see details"
      end
    end

    context "when there are subvolume actions" do
      let(:compound_actions) { [ca_create_device, ca_create_subvol, ca_delete_device, ca_delete_subvol] }

      it "presents collapsed subvolumes by default" do
        expect(subject.to_html).to include "see details"
        expect(subject.to_html).not_to include "delete subvolume"
        expect(subject.to_html).not_to include "create subvolume"
      end

      context "when subvolume actions are expanded" do
        before do
          allow(subject).to receive(:collapsed_subvolumes?).and_return(false)
        end

        it "presents delete subvolume actions first" do
          expect(subject.to_html)
            .to include "<li><b>delete subvolume action</b></li><li>create subvolume action</li>"
        end
      end
    end
  end

  describe "#events" do
    before do
      allow(subject).to receive(:toggle_subvolumes_event).and_return("subvolumes")
    end

    it "returns a list of strings" do
      expect(subject.events).to all(be_a(String))
    end

    it "includes toggle subvolumes event" do
      expect(subject.events).to include("subvolumes")
    end
  end
end
