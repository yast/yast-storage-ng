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

  describe "#store" do
    before do
      allow(subject).to receive(:value).and_return(value)
    end

    let(:value) { Y2Storage::Filesystems::MountByType::ID }

    it "updates the default mount by value" do
      expect(Y2Storage::StorageManager.instance.default_mount_by.to_sym).to_not eq(value)
      subject.store
      expect(Y2Storage::StorageManager.instance.default_mount_by).to eq(value)
    end

    it "saves the selected value into the config file" do
      expect(Y2Storage::SysconfigStorage.instance).to receive(:default_mount_by=).with(value)
      subject.store
    end
  end
end
