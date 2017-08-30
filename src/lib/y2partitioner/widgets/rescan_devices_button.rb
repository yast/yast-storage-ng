require "yast"
require "cwm/widget"
require "y2partitioner/device_graphs"
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

      def label
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
          # TRANSLATORS
          _("Re-scanning the storage devices will invalidate all the configuration options\n"\
            "set in the installer regarding storage, with no possibility to withdraw.\n\n" \
            "That includes the result and settings of the guided setup as well as the manual\n"\
            "changes performed in the expert partitioner.")
        else
          # TRANSLATORS
          _("Re-scanning the storage devices will invalidate all the previous changes with\n"\
            "no possibility to withdraw.")
        end
      end

      # Reprobes and updates devicegraphs for the partitioner
      #
      # @note A message is shown during the reprobing action
      def reprobe
        Yast::Popup.Feedback("", _("Rescanning disks...")) do
          Y2Storage::StorageManager.instance.probe
          probed = Y2Storage::StorageManager.instance.probed
          staging = Y2Storage::StorageManager.instance.staging
          DeviceGraphs.create_instance(probed, staging)
        end
      end
    end
  end
end
