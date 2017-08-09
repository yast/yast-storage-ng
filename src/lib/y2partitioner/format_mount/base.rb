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

require "yast"
require "y2storage"
require "y2partitioner/format_mount/options"

module Y2Partitioner
  module FormatMount
    # Base class for handle common format and mount operations
    class Base
      # params partition [Y2Storage::BlkDevice]
      # @param options [Options]
      def initialize(partition, options)
        @partition = partition
        @options = options
      end

      def apply_options!
        @partition.id = @options.partition_id
        apply_format_options!
        apply_mount_options!
      end

      def apply_format_options!
        return false unless @options.encrypt || @options.format

        @partition.remove_descendants

        if @options.encrypt
          @partition = @partition.create_encryption("cr_#{@partition.basename}")
          @partition.password = @options.password
        end

        if @options.format
          filesystem = @partition.create_filesystem(@options.filesystem_type)

          if filesystem.supports_btrfs_subvolumes?
            default_path = Y2Storage::Filesystems::Btrfs.default_btrfs_subvolume_path
            filesystem.ensure_default_btrfs_subvolume(path: default_path)
          end
        end

        true
      end

      def apply_mount_options!
        return false unless @partition.filesystem

        if @options.mount
          @partition.filesystem.mount_point = @options.mount_point
          @partition.filesystem.mount_by = @options.mount_by
          @partition.filesystem.label = @options.label if @options.label
          @partition.filesystem.fstab_options = @options.fstab_options
        else
          @partition.filesystem.mount_point = ""
        end

        true
      end
    end
  end
end
