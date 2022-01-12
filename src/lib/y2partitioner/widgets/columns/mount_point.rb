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

require "yast"
require "y2partitioner/widgets/columns/base"

module Y2Partitioner
  module Widgets
    module Columns
      # Widget for displaying the `Mount Point` column
      class MountPoint < Base
        # Constructor
        def initialize
          super
          textdomain "storage"
        end

        # @see Columns::Base#title
        def title
          # TRANSLATORS: table header, where is device mounted. Can be empty. E.g. "/" or "/home"
          _("Mount Point")
        end

        # @see Columns::Base#value_for
        def value_for(device)
          return left_to_right(device.mount_point) if fstab_entry?(device)

          mount_point = mount_point_for(device)

          return "" unless mount_point

          path = left_to_right(mount_point.path)
          path += " *" unless mount_point.active?

          path
        end

        private

        # Mount point for the given device
        #
        # @return [Y2Storage::MountPoint, nil]
        def mount_point_for(device)
          return device.mount_point if device.is?(:btrfs_subvolume)

          filesystem = filesystem_for(device)

          return nil if !filesystem || part_of_multidevice?(device, filesystem)

          filesystem.mount_point
        end
      end
    end
  end
end
