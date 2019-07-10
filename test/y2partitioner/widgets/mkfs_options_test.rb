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
# find current contact information at www.suse.com.

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/mkfs_options"
require "y2partitioner/actions/controllers"

RSpec.shared_examples "CWM::AbstractWidget#init#store" do
  describe "#init" do
    it "does not crash" do
      next unless subject.respond_to?(:init)

      expect { subject.init }.to_not raise_error
    end
  end

  describe "#store" do
    it "does not crash" do
      next unless subject.respond_to?(:store)

      expect { subject.store }.to_not raise_error
    end
  end
end

describe Y2Partitioner::Widgets do
  before { devicegraph_stub("windows-linux-multiboot-pc.yml") }

  let(:blk_device) { Y2Storage::Partition.find_by_name(fake_devicegraph, "/dev/sda1") }
  let(:controller) { Y2Partitioner::Actions::Controllers::Filesystem.new(blk_device, "XXX") }
  let(:all_options) { Y2Partitioner::Widgets::MkfsOptiondata.all }
  let(:a_inputfield) { all_options.find { |x| x.widget == :MkfsInputField } }
  let(:a_checkbox) { all_options.find { |x| x.widget == :MkfsCheckBox } }
  let(:a_combobox) { all_options.find { |x| x.widget == :MkfsComboBox } }

  describe Y2Partitioner::Widgets::MkfsOptions do
    subject { described_class.new(controller) }

    include_examples "CWM::CustomWidget"
  end

  describe Y2Partitioner::Widgets::MkfsInputField do
    subject { described_class.new(controller, a_inputfield) }

    include_examples "CWM::AbstractWidget"
    include_examples "CWM::AbstractWidget#init#store"
  end

  describe Y2Partitioner::Widgets::MkfsCheckBox do
    subject { described_class.new(controller, a_checkbox) }

    include_examples "CWM::AbstractWidget"
    include_examples "CWM::AbstractWidget#init#store"
  end

  describe Y2Partitioner::Widgets::MkfsComboBox do
    subject { described_class.new(controller, a_combobox) }

    include_examples "CWM::AbstractWidget"
    include_examples "CWM::ItemsSelection"
    include_examples "CWM::AbstractWidget#init#store"
  end
end
