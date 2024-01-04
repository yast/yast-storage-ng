#!/usr/bin/env rspec
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
# find current contact information at www.suse.com.

require_relative "../../../spec_helper"
require "y2storage/dialogs/guided_setup/widgets/partition_actions"

describe Y2Storage::Dialogs::GuidedSetup::Widgets::PartitionActions do
  subject { described_class.new(widget_id, settings, windows:, linux:, other:) }

  let(:widget_id) { "partition_actions" }

  let(:settings) { Y2Storage::ProposalSettings.new }

  let(:windows) { nil }

  let(:linux) { nil }

  let(:other) { nil }

  describe "#content" do
    context "when :windows option is set to true" do
      let(:windows) { true }

      it "contains a widget for the Windows partitions actions" do
        expect(Y2Storage::Dialogs::GuidedSetup::Widgets::WindowsPartitionActions)
          .to receive(:new).and_call_original

        subject.content
      end
    end

    context "when :windows option is set to false" do
      let(:windows) { false }

      it "does not contain a widget for the Windows partitions actions" do
        expect(Y2Storage::Dialogs::GuidedSetup::Widgets::WindowsPartitionActions).to_not receive(:new)

        subject.content
      end
    end

    context "when :linux option is set to true" do
      let(:linux) { true }

      it "contains an enabled widget for the Linux partitions actions" do
        expect(Y2Storage::Dialogs::GuidedSetup::Widgets::LinuxPartitionActions)
          .to receive(:new).with(anything, anything, hash_including(enabled: true)).and_call_original

        subject.content
      end
    end

    context "when :linux option is set to false" do
      let(:linux) { false }

      it "contains a disabled widget for the Linux partitions actions" do
        expect(Y2Storage::Dialogs::GuidedSetup::Widgets::LinuxPartitionActions)
          .to receive(:new).with(anything, anything, hash_including(enabled: false)).and_call_original

        subject.content
      end
    end

    context "when :other option is set to true" do
      let(:other) { true }

      it "contains an enabled widget for the other partitions actions" do
        expect(Y2Storage::Dialogs::GuidedSetup::Widgets::OtherPartitionActions)
          .to receive(:new).with(anything, anything, hash_including(enabled: true)).and_call_original

        subject.content
      end
    end

    context "when :other option is set to false" do
      let(:other) { false }

      it "contains a disabled widget for the other partitions actions" do
        expect(Y2Storage::Dialogs::GuidedSetup::Widgets::OtherPartitionActions)
          .to receive(:new).with(anything, anything, hash_including(enabled: false)).and_call_original

        subject.content
      end
    end
  end

  shared_context "all widgets" do
    before do
      allow(Y2Storage::Dialogs::GuidedSetup::Widgets::WindowsPartitionActions)
        .to receive(:new).and_return(windows_widget)

      allow(Y2Storage::Dialogs::GuidedSetup::Widgets::LinuxPartitionActions)
        .to receive(:new).and_return(linux_widget)

      allow(Y2Storage::Dialogs::GuidedSetup::Widgets::OtherPartitionActions)
        .to receive(:new).and_return(other_widget)
    end

    let(:windows_widget) do
      instance_double(Y2Storage::Dialogs::GuidedSetup::Widgets::WindowsPartitionActions,
        init: true, store: true)
    end

    let(:linux_widget) do
      instance_double(Y2Storage::Dialogs::GuidedSetup::Widgets::LinuxPartitionActions,
        init: true, store: true)
    end

    let(:other_widget) do
      instance_double(Y2Storage::Dialogs::GuidedSetup::Widgets::OtherPartitionActions,
        init: true, store: true)
    end
  end

  describe "#init" do
    include_context "all widgets"

    let(:windows) { true }

    it "initializes all widgets" do
      expect(windows_widget).to receive(:init)
      expect(linux_widget).to receive(:init)
      expect(other_widget).to receive(:init)

      subject.init
    end
  end

  describe "#store" do
    include_context "all widgets"

    let(:windows) { true }

    it "stores all widgets" do
      expect(windows_widget).to receive(:store)
      expect(linux_widget).to receive(:store)
      expect(other_widget).to receive(:store)

      subject.store
    end
  end

  describe "#help" do
    it "includes help for general options" do
      expect(subject.help).to match(/what to do with existing partitions/)
    end

    context "and :windows option is set to true" do
      let(:windows) { true }

      it "includes help for Windows options" do
        expect(subject.help).to match(/for Windows partitions/)
      end
    end

    context "and :windows option is set to false" do
      let(:windows) { false }

      it "does not include help for Windows options" do
        expect(subject.help).to_not match(/for Windows partitions/)
      end
    end
  end
end
