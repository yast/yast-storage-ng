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
require_relative "button_examples"

require "y2partitioner/widgets/tmpfs_buttons"

describe Y2Partitioner::Widgets::TmpfsAddButton do
  let(:action) { Y2Partitioner::Actions::AddTmpfs }

  let(:scenario) { "one-empty-disk" }

  include_examples "add button"
end

describe Y2Partitioner::Widgets::TmpfsEditButton do
  let(:action) { Y2Partitioner::Actions::EditTmpfs }

  let(:scenario) { "tmpfs1-devicegraph.xml" }

  let(:device) { devicegraph.tmp_filesystems.last }

  include_examples "button"
end

describe Y2Partitioner::Widgets::TmpfsDeleteButton do
  let(:action) { Y2Partitioner::Actions::DeleteTmpfs }

  let(:scenario) { "tmpfs1-devicegraph.xml" }

  let(:device) { devicegraph.tmp_filesystems.first }

  include_examples "button"
end
