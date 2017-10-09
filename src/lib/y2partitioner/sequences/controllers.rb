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

module Y2Partitioner
  # Namespace for all the UI::Sequence objects of the expert partitioner
  module Sequences
    # The different classes on this namespace store information about a device
    # being created or modified in a sequence and take care of updating the
    # devicegraph when needed according to that information. That glues
    # the different dialogs across the process, all together and to the
    # devicegraph.
    module Controllers
    end
  end
end

require "y2partitioner/sequences/controllers/filesystem"
require "y2partitioner/sequences/controllers/md"
require "y2partitioner/sequences/controllers/partition"
require "y2partitioner/sequences/controllers/lvm_lv"
