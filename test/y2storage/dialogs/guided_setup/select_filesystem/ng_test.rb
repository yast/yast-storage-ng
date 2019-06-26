#!/usr/bin/env rspec
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

require_relative "../../../spec_helper.rb"
require_relative "#{TEST_PATH}/support/guided_setup_context"

describe Y2Storage::Dialogs::GuidedSetup::SelectFilesystem::Ng do
  include_context "guided setup requirements"

  subject(:dialog) { described_class.new(guided_setup) }

  before { allow(settings).to receive(:volumes).and_return volumes }

  let(:widget_class) { Y2Storage::Dialogs::GuidedSetup::SelectFilesystem::VolumeWidget }

  describe "#run" do
    let(:volumes) do
      [
        double("VolumeSpecification", configurable?: true),
        double("VolumeSpecification", configurable?: false),
        double("VolumeSpecification", configurable?: true)
      ]
    end

    let(:widget0) { double("VolumeWidget", content: [], init: true, store: true) }
    let(:widget2) { double("VolumeWidget", content: [], init: true, store: true) }

    it "shows a VolumeWidget for every configurable volume" do
      expect(widget_class).to receive(:new).with(settings, 0).and_return widget0
      expect(widget_class).to receive(:new).with(settings, 2).and_return widget2
      expect(widget0).to receive(:content)
      expect(widget0).to receive(:init)
      expect(widget2).to receive(:content)
      expect(widget2).to receive(:init)

      dialog.run
    end

    it "ignores volumes that are not configurable" do
      expect(widget_class).to_not receive(:new).with(settings, 1)
      dialog.run
    end

    it "calls VolumeWidget#store for all the widgets" do
      allow(widget_class).to receive(:new).and_return(widget0, widget2)
      expect(widget0).to receive(:store)
      expect(widget2).to receive(:store)

      dialog.run
    end
  end

  describe "skip?" do
    before do
      allow(Y2Storage::Dialogs::GuidedSetup).to receive(:allowed?).and_return(allowed)
    end

    context "when the Guided Setup is not allowed" do
      let(:allowed) { false }

      let(:volumes) { [double("VolumeSpecification", configurable?: true)] }

      it "returns true" do
        expect(dialog.skip?).to eq(true)
      end
    end

    context "when the Guided Setup is allowed" do
      let(:allowed) { true }

      context "and the proposal settings contain no volumes" do
        let(:volumes) { [] }

        it "returns true" do
          expect(dialog.skip?).to eq true
        end
      end

      context "and none of the volumes are configurable" do
        let(:volumes) do
          [
            double("VolumeSpecification", configurable?: false),
            double("VolumeSpecification", configurable?: false)
          ]
        end

        it "returns true" do
          expect(dialog.skip?).to eq true
        end
      end

      context "and any volume is configurable" do
        let(:volumes) do
          [
            double("VolumeSpecification", configurable?: false),
            double("VolumeSpecification", configurable?: true)
          ]
        end

        it "returns false" do
          expect(dialog.skip?).to eq false
        end
      end
    end
  end

  describe "#handle_event" do
    let(:volumes) do
      [
        double("VolumeSpecification", configurable?: true),
        double("VolumeSpecification", configurable?: true)
      ]
    end
    let(:widget0) { double("VolumeWidget") }
    let(:widget1) { double("VolumeWidget") }
    let(:event) { "an event" }

    it "delegates to the #handle method of all volume widgets" do
      allow(widget_class).to receive(:new).and_return(widget0, widget1)
      expect(widget0).to receive(:handle).with(event)
      expect(widget1).to receive(:handle).with(event)
      dialog.handle_event(event)
    end
  end
end
