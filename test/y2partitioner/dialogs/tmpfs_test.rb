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
# find current contact information at www.suse.com.

require_relative "../test_helper"

require "cwm/rspec"
require "y2storage"
require "y2partitioner/dialogs/tmpfs"
require "y2partitioner/actions/controllers"

describe Y2Partitioner::Dialogs::Tmpfs do
  before { devicegraph_stub("tmpfs1-devicegraph.xml") }

  let(:filesystem) { fake_devicegraph.tmp_filesystems.first }
  let(:controller) do
    Y2Partitioner::Actions::Controllers::Filesystem.new(filesystem, "")
  end

  subject { described_class.new(controller) }

  include_examples "CWM::Dialog"
end
