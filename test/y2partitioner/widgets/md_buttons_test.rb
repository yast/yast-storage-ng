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

require "y2partitioner/widgets/md_buttons"

describe Y2Partitioner::Widgets::MdAddButton do
  let(:action) { Y2Partitioner::Actions::AddMd }

  let(:scenario) { "one-empty-disk" }

  include_examples "add button"
end

describe Y2Partitioner::Widgets::MdDevicesEditButton do
  let(:action) { Y2Partitioner::Actions::EditMdDevices }

  let(:scenario) { "md_raid" }

  let(:device) { devicegraph.find_by_name("/dev/md/md0") }

  include_examples "button"
end

describe Y2Partitioner::Widgets::MdDeleteButton do
  let(:action) { Y2Partitioner::Actions::DeleteMd }

  let(:scenario) { "md_raid" }

  let(:device) { devicegraph.find_by_name("/dev/md/md0") }

  include_examples "button"
end
