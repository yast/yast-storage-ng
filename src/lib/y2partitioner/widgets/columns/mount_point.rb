# Copyright (c) [2020-2022] SUSE LLC
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
          super()

          textdomain "storage"
        end

        # @see Columns::Base#title
        def title
          # TRANSLATORS: table header, where the device is mounted.
          _("Mount Point")
        end

        # @see Columns::Base#value_for
        #
        # @param device
        #   [Y2Storage::Device, Y2Storage::SimpleEtcFstabEntry, Y2Storage::Filesystems::LegacyNfs]
        def value_for(device)
          path = left_to_right(mount_path(device))

          path += " *" if mark_as_inactive?(device)

          path
        end

        private

        # Mount path of the given device or empty if the device has no mount point
        #
        # @param device
        #   [Y2Storage::Device, Y2Storage::SimpleEtcFstabEntry, Y2Storage::Filesystems::LegacyNfs]
        # @return [String]
        def mount_path(device)
          path =
            if fstab_entry?(device)
              device.mount_point
            elsif legacy_nfs?(device)
              device.mountpoint
            else
              mount_point_for(device)&.path
            end

          path || ""
        end

        # Whether the mount point of the device should be marked as inactive
        #
        # @param device
        #   [Y2Storage::Device, Y2Storage::SimpleEtcFstabEntry, Y2Storage::Filesystems::LegacyNfs]
        # @return [Boolean]
        def mark_as_inactive?(device)
          return false if fstab_entry?(device)

          return !device.active? if legacy_nfs?(device)

          mount_point = mount_point_for(device)

          mount_point.nil? ? false : !mount_point.active?
        end
      end
    end
  end
end
