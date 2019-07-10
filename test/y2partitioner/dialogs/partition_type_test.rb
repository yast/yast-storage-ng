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

require "cwm/rspec"
require "y2partitioner/dialogs/partition_type"

describe Y2Partitioner::Dialogs::PartitionType do
  let(:controller) do
    double(
      "PartitionController",
      unused_slots: slots, unused_optimal_slots: slots, disk_name: "/dev/sda", wizard_title: ""
    )
  end
  let(:slots) { [] }

  subject { described_class.new(controller) }
  before do
    allow(Y2Partitioner::Dialogs::PartitionType::TypeChoice)
      .to receive(:new).and_return(term(:Empty))
  end
  include_examples "CWM::Dialog"
end

describe Y2Partitioner::Dialogs::PartitionType::TypeChoice do
  let(:controller) do
    double(
      "PartitionController", unused_slots: slots, unused_optimal_slots: slots, disk_name: "/dev/sda"
    )
  end
  let(:slots) { [double("Slot", :"possible?" => true)] }

  subject { described_class.new(controller) }

  include_examples "CWM::RadioButtons"
end
