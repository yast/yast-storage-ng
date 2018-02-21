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

require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::Settings do
  subject(:page) { described_class.new }

  include_examples "CWM::Page"

  describe "#contents" do
    it "includes a widget to select default mount by" do
      expect(Y2Partitioner::Widgets::Pages::Settings::MountBySelector).to receive(:new)
      page.contents
    end
  end
end

describe Y2Partitioner::Widgets::Pages::Settings::MountBySelector do
  include_examples "CWM::ComboBox"

  describe "#handle" do
    before do
      allow(subject).to receive(:value).and_return(value)
      allow(subject).to receive(:widget_id).and_return(widget_id)

      Y2Storage::StorageManager.instance.default_mount_by = mount_by_label
      Y2Storage::SysconfigStorage.instance.default_mount_by = mount_by_label
    end

    let(:value) { mount_by_id }

    let(:widget_id) { "a_widget_id" }

    let(:mount_by_id) { Y2Storage::Filesystems::MountByType::ID }

    let(:mount_by_label) { Y2Storage::Filesystems::MountByType::LABEL }

    context "when a mount_by is selected" do
      let(:events) { { "ID" => widget_id } }

      it "updates the default value for mount_by" do
        expect(Y2Storage::StorageManager.instance.default_mount_by).to_not eq(value)
        subject.handle(events)
        expect(Y2Storage::StorageManager.instance.default_mount_by).to eq(value)
      end

      it "saves the selected value into the config file" do
        expect(Y2Storage::SysconfigStorage.instance.default_mount_by).to_not eq(value)
        subject.handle(events)
        expect(Y2Storage::SysconfigStorage.instance.default_mount_by).to eq(value)
      end
    end

    context "when other widget has changed" do
      let(:events) { { "ID" => "other_widget_id" } }

      it "does not update the default value for mount_by" do
        expect(Y2Storage::StorageManager.instance.default_mount_by.to_sym).to_not eq(value)
        subject.handle(events)
        expect(Y2Storage::StorageManager.instance.default_mount_by).to_not eq(value)
      end

      it "does not save the selected value into the config file" do
        expect(Y2Storage::SysconfigStorage.instance.default_mount_by).to_not eq(value)
        subject.handle(events)
        expect(Y2Storage::SysconfigStorage.instance.default_mount_by).to_not eq(value)
      end
    end
  end
end
