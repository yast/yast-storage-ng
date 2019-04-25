# encoding: utf-8

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
          [:fs_type, :mount_point, :mount_by, :label, :uuid]
        end

        # Information about the filesystem type
        #
        # @return [String]
        def fs_type_value
          type = filesystem ? filesystem.type.to_human_string : ""

          # TRANSLATORS: Filesystem type information, where %s is replaced by
          # a filesystem type (e.g., VFAT, BTRFS)
          format(_("File System: %s"), type)
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

        # Whether the mount point is inactive
        #
        # @return [Boolean]
        def mount_point_inactive?
          return false unless filesystem && filesystem.mount_point

          !filesystem.mount_point.active?
        end

        # Mount by value from the mount point
        #
        # @return [String]
        def mount_by
          return "" unless filesystem && filesystem.mount_point

          filesystem.mount_point.mount_by.to_human_string
        end
      end
    end
  end
end
