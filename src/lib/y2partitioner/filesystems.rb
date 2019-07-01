# Copyright (c) [2019] SUSE LLC
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

require "y2storage/filesystems/type"

module Y2Partitioner
  # Module with information about filesystem types that the Partitioner supports
  #
  # The Partitioner has a limited list of possible filesystem types (basically for
  # historic reasons). `libstorage-ng` supports quite some filesystems that are not
  # offered by the Partitioner.
  module Filesystems
    SUPPORTED_FILESYSTEM_TYPES = [:swap, :btrfs, :ext2, :ext3, :ext4, :vfat, :xfs, :udf].freeze

    # All filesystem types that the Partitioner supports
    #
    # @return [Array<Y2Storage::Filesystems::Type>]
    def self.all
      Y2Storage::Filesystems::Type.all.select { |f| supported?(f) }
    end

    # Whether a filesystem type is supported by the Partitioner
    #
    # @param fs_type [Y2Storage::Filesystems::Type]
    # @return [Boolean]
    def self.supported?(fs_type)
      SUPPORTED_FILESYSTEM_TYPES.include?(fs_type.to_sym)
    end
  end
end
