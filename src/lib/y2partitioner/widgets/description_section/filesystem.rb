# Copyright (c) [2019-2020] SUSE LLC
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

require "y2partitioner/widgets/description_section/base"

module Y2Partitioner
  module Widgets
    module DescriptionSection
      # Description section with specific data about a filesystem
      class Filesystem < Base
        # Constructor
        #
        # @param device [Y2Storage::Filesystems::Base]
        def initialize(device)
          textdomain "storage"

          super
        end

        private

        alias_method :filesystem, :device

        # @see DescriptionSection::Base#title
        def title
          # TRANSLATORS: title for section about filesystem details
          _("File System:")
        end

        # @see DescriptionSection::Base#entries
        def entries
          [:fs_type, :mount_point, :mount_by, :label, :uuid] + ext_entries + btrfs_entries
        end

        # Extra entries when the filesystem is Btrfs
        #
        # @return [Array<Symbol>]
        def btrfs_entries
          return [] unless filesystem&.is?(:btrfs)

          [:btrfs_data_raid_level, :btrfs_metadata_raid_level, :btrfs_devices]
        end

        # Extra entries when the filesystem is Ext
        #
        # @return [Array<Symbol>]
        def ext_entries
          return [] unless filesystem&.type&.is?(:ext3, :ext4)

          [:journal]
        end

        # Information about the filesystem type
        #
        # @return [String]
        def fs_type_value
          type = filesystem ? filesystem.type.to_human_string : ""

          # TRANSLATORS: Filesystem type information, where %s is replaced by
          # a filesystem type (e.g., VFAT, BTRFS)
          format(_("Type: %s"), type)
        end

        # Information about the mount point
        #
        # @return [String]
        def mount_point_value
          mount_point = filesystem ? filesystem.mount_path : ""
          mount_point ||= ""

          # TRANSLATORS: Mount point information, where %s is replaced by a mount point
          res = format(_("Mount Point: %s"), mount_point)
          # TRANSLATORS: note appended to mount point if mount point is not now mounted
          res += _(" (not mounted)") if mount_point_inactive?

          res
        end

        # Entry data about the mount by option
        #
        # @return [String]
        def mount_by_value
          # TRANSLATORS: Mount by information, where %s is replaced by a "mount by" option
          format(_("Mount By: %s"), mount_by)
        end

        # Entry data about the filesystem label
        #
        # @return [String]
        def label_value
          label = filesystem ? filesystem.label : ""

          # TRANSLATORS: Filesystem label information, where %s is replaced by the
          # filesystem label
          format(_("Label: %s"), label)
        end

        # Entry data about the filesystem UUID
        #
        # @return [String]
        def uuid_value
          uuid = filesystem ? filesystem.uuid : ""

          # TRANSLATORS: Filesystem UUID information, where %s is replaced by the
          # filesystem UUID
          format(_("UUID: %s"), uuid)
        end

        # Information about the data RAID level
        #
        # @return [String]
        def btrfs_data_raid_level_value
          level = filesystem.data_raid_level.to_human_string

          # TRANSLATORS: Btrfs data information, where %s is replaced by a RAID level (e.g., RAID0).
          format(_("RAID Level: %s"), level)
        end

        # Information about the metadata RAID level
        #
        # @return [String]
        def btrfs_metadata_raid_level_value
          level = filesystem.metadata_raid_level.to_human_string

          # TRANSLATORS: Btrfs metadata information, where %s is replaced by a RAID level (e.g., RAID0).
          format(_("Metadata RAID Level: %s"), level)
        end

        # Information about the devices used by the Btrfs filesystem
        #
        # @return [String]
        def btrfs_devices_value
          devices = filesystem.plain_blk_devices.map(&:name)

          # TRANSLATORS: Information abut devices used by a Btrfs filesystem, where %s is replaced by a
          #   comma separated list of device names (e.g., "/dev/sda1, /dev/sda2").
          format(_("Used Devices: %s"), Yast::HTML.List(devices))
        end

        # Whether the mount point is inactive
        #
        # @return [Boolean]
        def mount_point_inactive?
          return false unless filesystem&.mount_point

          !filesystem.mount_point.active?
        end

        # Mount by value from the mount point
        #
        # @return [String]
        def mount_by
          return "" unless filesystem&.mount_point

          filesystem.mount_point.mount_by.to_human_string
        end

        # Information about journal
        #
        # @return [String]
        def journal_value
          format(_("Journal Device: %s"), filesystem&.journal_device&.name)
        end
      end
    end
  end
end
