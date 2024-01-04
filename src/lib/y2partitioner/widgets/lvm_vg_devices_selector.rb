# Copyright (c) [2018-2021] SUSE LLC
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
require "y2partitioner/widgets/devices_selection"
require "yast2/popup"

module Y2Partitioner
  module Widgets
    # Widget making possible to add and remove physical volumes to a LVM volume group
    class LvmVgDevicesSelector < Widgets::DevicesSelection
      # Constructor
      #
      # @param controller [Actions::Controllers::LvmVg]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
        super()
      end

      def help
        help_available_pvs + help_selected_pvs
      end

      def help_available_pvs
        _("<p><b>Available Devices:</b> " \
          "A list of available LVM physical volumes. " \
          "If this list is empty, you need to create partitions " \
          "as \"Raw Volume (unformatted)\" with partition ID \"Linux LVM\"" \
          "in the \"Hard Disks\" view of the partitioner." \
          "</p>")
      end

      def help_selected_pvs
        _("<p><b>Selected Devices:</b> " \
          "The physical volumes to create this volume group from. " \
          "If needed, you can always add more physical volumes later." \
          "</p>")
      end

      # @see Widgets::DevicesSelection#selected
      def selected
        controller.devices_in_vg
      end

      # @see Widgets::DevicesSelection#selected_size
      def selected_size
        controller.vg_size
      end

      # @see Widgets::DevicesSelection#unselected
      def unselected
        controller.available_devices
      end

      # @see Widgets::DevicesSelection#select
      def select(sids)
        find_by_sid(unselected, sids).each do |device|
          controller.add_device(device)
        end
      end

      # @see Widgets::DevicesSelection#unselect
      #
      # @note Committed physical volumes cannot be unselected,
      #   see {#check_for_committed_devices}.
      def unselect(sids)
        check_for_committed_devices(sids)
        sids -= controller.committed_devices.map(&:sid)

        find_by_sid(selected, sids).each do |device|
          controller.remove_device(device)
        end
      end

      # Validates the selected physical volumes
      #
      # An error popup is shown when there is some error.
      #
      # @return [Boolean]
      def validate
        errors = send(:errors)

        return true if errors.none?

        Yast2::Popup.show(errors.first, headline: :error)
        false
      end

      private

      # @return [Actions::Controllers::LvmVg]
      attr_reader :controller

      # Errors when selecting physical volumes
      #
      # @return [Array<String>]
      def errors
        [devices_error, size_error, striped_lvs_devices_error, striped_lvs_size_error].compact
      end

      # Error when no physical volume is selected
      #
      # @return [String, nil] nil if physical volumes are selected
      def devices_error
        return nil if controller.devices_in_vg.size > 0

        # TRANSLATORS: Error message
        _("Select at least one device.")
      end

      # Error when the volume group size is not big enough to allocate all its logical volumes
      #
      # @return [String, nil] nil if the volume group is big enough
      def size_error
        return nil if controller.vg_size >= controller.lvs_size

        # TRANSLATORS: Error message where %s is replaced by a size (e.g., 4 GiB).
        format(_("The volume group size cannot be less than %s."), controller.lvs_size)
      end

      # Error message when the selected physical volumes cannot allocate the striped volumes
      #
      # @return [String, nil]
      def striped_lvs_devices_error
        return nil if controller.devices_in_vg.size >= controller.lvs_stripes

        format(
          # TRANSLATORS: Error message, where %s is replaced by a number (e.g., 3).
          _("The number of physcal volumes is not enough. The volume group contains striped logical " \
            "volumes. Please, select at least %s devices in order to satisfy the number of stripes of " \
            "the current volumes."),
          controller.lvs_stripes
        )
      end

      # Error message when the volume group has no enough size to allocate each striped volume
      #
      # @return [String, nil]
      def striped_lvs_size_error
        return nil if controller.size_for_striped_lvs?

        # TRANSLATORS: Error message
        _("The volume group contains striped logical volumes and the selected devices are too small " \
          "to allocate them. Note that the size of a striped volume is limited by its number of " \
          "stripes and the size of the physical volumes.")
      end

      # Checks whether committed devices have been selected for removing, showing an error
      # popup is that case
      #
      # @see Actions::Controllers::LvmVg#committed_devices
      #
      # @param sids [Array<Integer>]
      def check_for_committed_devices(sids)
        committed_devices = controller.committed_devices.select { |d| sids.include?(d.sid) }
        return if committed_devices.empty?

        error_message = if committed_devices.size > 1
          # TRANSLATORS: Error message when several physical volumes cannot be removed, where
          # %{pvs} is replaced by device names (e.g., /dev/sda1, /dev/sda2) and %{vg} is
          # replaced by the volume group name (e.g., system)
          _("Removing physical volumes %{pvs} from the volume group %{vg}\n" \
            "is not supported because the physical volumes may be already in use")
        else
          # TRANSLATORS: Error message when a physical volume cannot be removed, where
          # %{pvs} is replaced by device name (e.g., /dev/sda1) and %{vg} is replaced
          # by the volume group name (e.g., system)
          _("Removing the physical volume %{pvs} from the volume group %{vg}\n" \
            "is not supported because the physical volume may be already in use")
        end

        pvs = committed_devices.map(&:name).join(", ")
        vg = controller.vg.vg_name

        Yast2::Popup.show(format(error_message, pvs:, vg:), headline: :error)
      end

      # Finds devices by sid
      #
      # @param devices [Array<Y2Storage::BlkDevice>]
      # @param sids [Array<Integer>]
      #
      # @return [Array<Y2Storage::BlkDevice>]
      def find_by_sid(devices, sids)
        devices.select { |d| sids.include?(d.sid) }
      end
    end
  end
end
