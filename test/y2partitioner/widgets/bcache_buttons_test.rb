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

require "y2partitioner/widgets/bcache_buttons"

describe Y2Partitioner::Widgets::BcacheAddButton do
  let(:action) { Y2Partitioner::Actions::AddBcache }

  let(:scenario) { "one-empty-disk" }

  include_examples "add button"
end

describe Y2Partitioner::Widgets::BcacheEditButton do
  let(:action) { Y2Partitioner::Actions::EditBcache }

  let(:scenario) { "bcache1.xml" }

  let(:device) { devicegraph.find_by_name("/dev/my_vg/bcache2") }

  include_examples "button"
end

describe Y2Partitioner::Widgets::BcacheDeleteButton do
  let(:action) { Y2Partitioner::Actions::DeleteBcache }

  let(:scenario) { "bcache1.xml" }

  let(:device) { devicegraph.find_by_name("/dev/my_vg/bcache2") }

  include_examples "button"
end
