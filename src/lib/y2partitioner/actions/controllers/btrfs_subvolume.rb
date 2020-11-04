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

require "y2partitioner/actions/controllers/base"

module Y2Partitioner
  module Actions
    module Controllers
      # Controller class to deal with Btrfs subvolumes
      class BtrfsSubvolume < Base
        # @return [Y2Storage::Filesystems::Btrfs]
        attr_reader :filesystem

        # @return [Y2Storage::BtrfsSubvolume, nil]
        attr_reader :subvolume

        # Path for the subvolume. Widgets set this value.
        #
        # @return [String]
        attr_accessor :subvolume_path

        # NoCoW attribute for the subvolume. Widgets set this value.
        #
        # @return [Boolean]
        attr_accessor :subvolume_nocow

        # Constructor
        #
        # @param filesystem [Y2Storage::Filesystems::Btrfs] filesystem to work on
        # @param subvolume [Y2Storage::BtrfsSubvolume] specific subvolume to work on (e.g., when editing)
        def initialize(filesystem, subvolume: nil)
          super()

          @filesystem = filesystem
          @subvolume = subvolume

          set_default_values
        end

        # Adds a new Btrfs subvolume
        #
        # @param path [String]
        # @param nocow [Booelan]
        def create_subvolume(path, nocow = false)
          @subvolume = filesystem.create_btrfs_subvolume(path, nocow)
        end

        # Updates the Btrfs subvolume properties
        def update_subvolume
          return unless subvolume

          if !exist_subvolume?
            filesystem.delete_btrfs_subvolume(subvolume.path)
            create_subvolume(subvolume_path)
          end

          subvolume.nocow = subvolume_nocow
        end

        # Prefix used for the subvolumes
        #
        # New subvolumes path should start by this prefix.
        #
        # @return [String]
        def subvolumes_prefix
          prefix = filesystem.subvolumes_prefix
          prefix << "/" unless prefix.empty?

          prefix
        end

        # Whether the subvolumes prefix should be added to the given path
        #
        # @return [Boolean]
        def missing_subvolumes_prefix?(path)
          !path.squeeze("/").sub(/^\//, "").start_with?(subvolumes_prefix)
        end

        # Adds the subvolumes prefix to the given path if needed
        #
        # @return [String]
        def add_subvolumes_prefix(path)
          return path unless missing_subvolumes_prefix?(path)

          canonical_name = filesystem.canonical_subvolume_name(path)

          filesystem.btrfs_subvolume_path(canonical_name)
        end

        # Whether the current subvolume already exists on disk
        #
        # @return [Boolean]
        def exist_subvolume?
          return false unless subvolume

          !new?(subvolume)
        end

        # Whether the filesystem already has a subvolume on disk with the given path
        #
        # @return [Boolean]
        def exist_path?(path)
          subvolume = filesystem.btrfs_subvolumes.find { |s| s.path == path }

          return false unless subvolume

          !new?(subvolume)
        end

        private

        # Default values for the subvolume attributes
        def set_default_values
          @subvolume_path = subvolumes_prefix
          @subvolume_nocow = false

          return unless subvolume

          @subvolume_path = subvolume.path
          @subvolume_nocow = subvolume.nocow?
        end
      end
    end
  end
end
