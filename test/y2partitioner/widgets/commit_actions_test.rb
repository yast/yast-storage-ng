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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/commit_actions"

describe Y2Partitioner::Widgets::CommitActions do
  before do
    storage = Y2Storage::StorageManager.create_test_instance
    Y2Partitioner::DeviceGraphs.create_instance(storage.probed, storage.staging)
  end

  subject { described_class.new }

  include_examples "CWM::CustomWidget"

  describe "#contents" do
    it "contains a widget to list the commit actions" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Widgets::CommitActions::Actions)
      end

      expect(widget).to_not be_nil
    end

    it "contains a progress bar" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Widgets::CommitActions::ProgressBar)
      end

      expect(widget).to_not be_nil
    end
  end

  describe "#init" do
    before do
      allow(Y2Storage::StorageManager.instance).to receive(:commit)

      allow(Y2Storage::Callbacks::Commit).to receive(:new).with(hash_including(widget: subject))
        .and_return(callbacks)
    end

    let(:callbacks) { instance_double(Y2Storage::Callbacks::Commit) }

    it "performs an storage commit with proper callbacks" do
      expect(Y2Storage::StorageManager.instance).to receive(:commit)
        .with(hash_including(callbacks:))

      subject.init
    end
  end

  describe "#handle" do
    it "auto-closes the dialog" do
      expect(subject.handle).to eq(:ok)
    end
  end

  describe "#add_action" do
    before do
      allow(subject).to receive(:actions_widget).and_return(actions_widget)

      allow(subject).to receive(:progress_bar_widget).and_return(progress_bar_widget)
    end

    let(:actions_widget) { Y2Partitioner::Widgets::CommitActions::Actions.new }

    let(:progress_bar_widget) { Y2Partitioner::Widgets::CommitActions::ProgressBar.new(10) }

    it "updates the list of actions" do
      expect(actions_widget).to receive(:value=).and_call_original

      subject.add_action("action message")
    end

    it "updates the progress bar" do
      expect(progress_bar_widget).to receive(:forward).and_call_original

      subject.add_action("action message")
    end
  end
end
