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

module Y2Storage
  # Y2Storage::AutoinstProblems offers an API to register and report storage
  # related AutoYaST problems.
  #
  # Basically, it works by registering found problems when creating the
  # partitioning proposal (based on AutoYaST profile) and displaying them to
  # the user. Check {Y2Storage::AutoinstProblems::Problem} in order to
  # find out more details about the kind of problems.
  #
  # About registering errors, an instance of the
  # {Y2Storage::AutoinstProblems::List} will be used.
  module AutoinstProblems
  end
end

require "y2storage/autoinst_problems/list"
require "y2storage/autoinst_problems/problem"
require "y2storage/autoinst_problems/invalid_value"
require "y2storage/autoinst_problems/missing_value"
require "y2storage/autoinst_problems/missing_root"
require "y2storage/autoinst_problems/exception"
require "y2storage/autoinst_problems/no_disk_space"
