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

module Y2Storage
  module AutoinstProfile
    # Thin object oriented layer on top of a <btrfs_options> section of the AutoYaST profile
    class BtrfsOptionsSection < SectionWithAttributes
      def self.attributes
        [
          { name: :data_raid_level },
          { name: :metadata_raid_level }
        ]
      end

      define_attr_accessors

      # @!attribute data_raid_level
      #   @return [String] Data RAID level of a multi-device Btrfs

      # @!attribute metadata_raid_level
      #   @return [String] Metadata RAID level of a multi-device Btrfs

      # @param parent [#parent, #section_name] parent section
      def initialize(parent = nil)
        @parent = parent
      end

      # Clones Btrfs options into an AutoYaST <btrfs_options> profile section
      #
      # @param filesystem [Filesystems::Btrfs]
      # @return [BtrfsOptionsSection] Btrfs options section
      def self.new_from_storage(filesystem)
        section = new
        section.init_from_btrfs(filesystem)
        section
      end

      # Method used by {.new_from_storage} to populate the attributes when cloning Btrfs options
      #
      # @param filesystem [Filesystems::Btrfs]
      def init_from_btrfs(filesystem)
        @data_raid_level = filesystem.data_raid_level.to_s
        @metadata_raid_level = filesystem.metadata_raid_level.to_s
      end
    end
  end
end
