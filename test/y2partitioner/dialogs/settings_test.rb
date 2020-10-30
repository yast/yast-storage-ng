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
require "y2partitioner/dialogs/settings"

describe Y2Partitioner::Dialogs::Settings do
  subject(:page) { described_class.new }

  include_examples "CWM::Dialog"

  describe "#contents" do
    it "includes a widget to select default mount by" do
      expect(Y2Partitioner::Dialogs::Settings::MountBySelector).to receive(:new)
      page.contents
    end
  end
end

describe Y2Partitioner::Dialogs::Settings::MountBySelector do
  include_examples "CWM::ComboBox"

  describe "#store" do
    before do
      allow(subject).to receive(:value).and_return(value)
      allow(subject).to receive(:widget_id).and_return(widget_id)

      allow(Yast::SCR).to receive(:Write)

      Y2Storage::StorageManager.create_test_instance
      configuration.default_mount_by = mount_by_label
    end

    let(:configuration) { Y2Storage::StorageManager.instance.configuration }

    let(:value) { mount_by_id }

    let(:widget_id) { "a_widget_id" }

    let(:mount_by_id) { Y2Storage::Filesystems::MountByType::ID }

    let(:mount_by_label) { Y2Storage::Filesystems::MountByType::LABEL }

    it "updates the default value for mount_by" do
      expect(configuration.default_mount_by).to_not eq(value)
      subject.store
      expect(configuration.default_mount_by).to eq(value)
    end

    it "saves the selected value into the config file" do
      expect(Yast::SCR).to receive(:Write) do |path, value|
        expect(path.to_s).to match(/storage/)
        expect(value).to eq("id")
      end

      subject.store
    end
  end
end
