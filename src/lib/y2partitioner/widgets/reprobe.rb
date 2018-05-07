# encoding: utf-8

# Copyright (c) [2017-2018] SUSE LLC
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

require "y2partitioner/device_graphs"
require "y2partitioner/exceptions"
require "y2storage/storage_manager"

module Y2Partitioner
  module Widgets
    # Mixin for widgets that need to trigger a hardware reprobe
    module Reprobe
    private

      # Reprobes and updates devicegraphs for the partitioner.
      #
      # @note A message is shown during the reprobing action.
      #
      # @raise [Y2Partitioner::ForcedAbortError] When there is an error during probing
      #   and the user decides to abort, or probed devicegraph contains errors and the
      #   user decides to not sanitize.
      def reprobe
        textdomain "storage"
        Yast::Popup.Feedback("", _("Rescanning disks...")) do
          probe_performed = Y2Storage::StorageManager.instance.probe
          raise Y2Partitioner::ForcedAbortError unless probe_performed

          probed = Y2Storage::StorageManager.instance.probed
          staging = Y2Storage::StorageManager.instance.staging
          DeviceGraphs.create_instance(probed, staging)
        end
      end
    end
  end
end
