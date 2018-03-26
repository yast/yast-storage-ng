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
require "cwm/widget"
require "y2partitioner/device_graphs"
require "y2partitioner/exceptions"
require "y2storage/storage_manager"

Yast.import "Popup"
Yast.import "Mode"

module Y2Partitioner
  module Widgets
    # Button for rescanning system devices
    class RescanDevicesButton < CWM::PushButton
      def initialize
        textdomain "storage"
      end

      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: button label to rescan devices
        _("Rescan Devices")
      end

      # Shows a confirm message before reprobing
      def handle
        return nil unless continue?

        reprobe
        :redraw
      end

    private

      def continue?
        Yast::Popup.YesNo(rescan_message)
      end

      def rescan_message
        if Yast::Mode.installation
          _("Re-scanning the storage devices will invalidate all the configuration\n" \
            "options set in the installer regarding storage, with no possibility\n" \
            "to withdraw.\n" \
            "That includes the result and settings of the guided setup as well as\n" \
            "the manual changes performed in the expert partitioner.")
        else
          _("Re-scanning the storage devices will invalidate all the previous\n" \
            "changes with no possibility to withdraw.")
        end
      end

      # Reprobes and updates devicegraphs for the partitioner.
      #
      # @note A message is shown during the reprobing action.
      #
      # @raise [Y2Partitioner::ForcedAbortError] When the probed devicegraph contains errors
      #   and the user decices to not sanitize
      def reprobe
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
