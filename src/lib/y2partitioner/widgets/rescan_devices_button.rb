require "yast"
require "cwm/widget"
require "y2partitioner/device_graphs"
require "y2storage/storage_manager"

Yast.import "Popup"

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
        Yast::Popup.YesNo(
          # TRANSLATORS
          format(
            _("Current changes will be discarted, including changes done by the proposal.\n" \
              "Do you want to continue?")
          )
        )
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
