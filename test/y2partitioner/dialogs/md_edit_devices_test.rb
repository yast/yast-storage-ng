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

require_relative "../test_helper"

require "yast"
require "cwm/rspec"
require "y2storage"
require "y2partitioner/dialogs/md_edit_devices"
require "y2partitioner/actions/controllers/md"

describe Y2Partitioner::Dialogs::MdEditDevices do
  before do
    Y2Storage::StorageManager.create_test_instance
  end

  let(:controller) { Y2Partitioner::Actions::Controllers::Md.new }

  subject { described_class.new(controller) }

  include_examples "CWM::Dialog"

  describe "#contents" do
    it "contains a widget for selecting devices" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Widgets::MdDevicesSelector)
      end
      expect(widget).to_not be_nil
    end
  end
end
