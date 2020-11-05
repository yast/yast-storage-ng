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

require "y2partitioner/widgets/description_section/base"

module Y2Partitioner
  module Widgets
    module DescriptionSection
      # Description section with specific data about a Btrfs subvolume
      class BtrfsSubvolume < Base
        # Constructor
        #
        # @param device [Y2Storage::BtrfsSubvolume]
        def initialize(device)
          textdomain "storage"

          super
        end

        private

        # @see Base#title
        def title
          # TRANSLATORS: title for the section about Btrfs subvolume details
          _("Btrfs Subvolume:")
        end

        # @see Base#entries
        def entries
          [:path, :mount_point, :mounted, :nocow]
        end

        # @see Base#entries_values
        def path_value
          # TRANSLATORS: Subvolume path information, where %s is replaced by a path (e.g., "@/home")
          format(_("Path: %s"), device.path)
        end

        # @see Base#entries_values
        def mount_point_value
          # TRANSLATORS: Mount point information, where %s is replaced by a mount point (e.g., "/home")
          format(_("Mount Point: %s"), device.mount_path)
        end

        # Information whether the subvolume is mounted
        #
        # Note that this information is about the current mount point assigned to the subvolume and not
        # necessarily about the real mount point of a probed subvolume.
        #
        # @see Base#entries_values
        def mounted_value
          mounted = (device.mount_point&.active?) ? _("Yes") : _("No")

          # TRANSLATORS: Mounted information, where %s is replaced by "Yes" or "No"
          format(_("Mounted: %s"), mounted)
        end

        # @see Base#entries_values
        def nocow_value
          nocow = device.nocow? ? _("Yes") : _("No")

          # TRANSLATORS: Subvolume noCoW information, where %s is replaced "Yes" or "No"
          format(_("noCoW: %s"), nocow)
        end
      end
    end
  end
end
