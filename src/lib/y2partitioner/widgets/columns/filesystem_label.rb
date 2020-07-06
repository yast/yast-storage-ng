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
      # Widget for displaying the `Label` column
      class FilesystemLabel < Base
        # @see Columns::Base#title
        def title
          # TRANSLATORS: table header, disk or partition label. Can be empty.
          _("Label")
        end

        # @see Columns::Base#value_for
        def value_for(device)
          return fstab_filesystem_label(device) if fstab_entry?(device)

          filesystem_label(device)
        end

        # @see Columns::Base#symbol
        def symbol
          :label
        end

        private

        # Returns the label for the given device, when possible
        #
        # @param device [Y2Storage::Device, Y2Storage::SimpleEtcFstabEntry, nil]
        # @return [String] the label if possible; empty string otherwise
        def filesystem_label(device)
          return "" unless device

          filesystem = filesystem_for(device)

          return "" unless filesystem
          return "" if part_of_multidevice?(device, filesystem)
          # fs may not supporting labels, like NFS
          return "" unless filesystem.respond_to?(:label)

          filesystem.label
        end

        # Returns the label for the given fstab entry, when possible
        #
        # @see #filesystem_label
        # @param fstab_entry [Y2Storage::SimpleEtcFstabEntry]
        def fstab_filesystem_label(fstab_entry)
          device = fstab_entry.device(system_graph)

          filesystem_label(device)
        end
      end
    end
  end
end
