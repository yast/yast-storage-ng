#!/usr/bin/env ruby
#
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

require "y2storage"

module Y2Partitioner
  module Refinements
    # Temporary refinement for Y2Storage::Filesystems::Type. It should be
    # replaced by a proper class or any other mechanism at some point.
    module FilesystemType
      refine Y2Storage::Filesystems::Type do
        def formattable?
          [:btrfs, :ext2, :ext3, :ext4, :swap, :vfat, :xfs].include?(to_sym)
        end

        def encryptable?
          formattable?
        end
      end
    end
  end
end
