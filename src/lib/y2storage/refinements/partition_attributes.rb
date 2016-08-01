#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

require "storage"
require "y2storage/disk_size"

module Y2Storage
  module Refinements
    # Refinements for Partition adding some virtual attributes, mainly used
    # to make the rspec tests more readable
    module PartitionAttributes
      refine ::Storage::Partition do
        # First mounpoint
        def mountpoint
          filesystem.mountpoints.first
        end

        # Label of the filesystem
        def label
          filesystem.label
        end

        # UUID of the filesystem
        def uuid
          filesystem.uuid
        end

      end
    end
  end
end
