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

require_relative "../test_helper"

require "yast"
require "cwm/rspec"
require "y2storage"
require "y2partitioner/dialogs/md_options"
require "y2partitioner/actions/controllers"

Yast.import "UI"

describe Y2Partitioner::Dialogs::MdOptions do
  before { devicegraph_stub("lvm-two-vgs.yml") }

  let(:controller) do
    Y2Partitioner::Actions::Controllers::Md.new
  end

  subject { described_class.new(controller) }

  include_examples "CWM::Dialog"

  describe Y2Partitioner::Dialogs::MdOptions::ChunkSize do
    include_examples "CWM::ComboBox"
  end

  describe Y2Partitioner::Dialogs::MdOptions::Parity do
    include_examples "CWM::ComboBox"
  end
end
