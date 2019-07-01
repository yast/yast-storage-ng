# Copyright (c) [2018] SUSE LLC
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
require "y2partitioner/ui_state"
require "y2partitioner/actions/delete_device"

module Y2Partitioner
  module Actions
    # Action for deleting all logical volumes of an LVM volume group
    #
    # @see DeleteDevice
    class DeleteLvmLvs < DeleteDevice
      def initialize(*args)
        super

        textdomain "storage"
      end

      private

      # Deletes all LVs (see {DeleteDevice#device})
      def delete
        log.info "deleting logical volumes from #{device}"

        device.lvm_lvs.each { |lv| device.delete_lvm_lv(lv) }
        UIState.instance.select_row(device)
      end

      # @see DeleteDevice#errors
      def errors
        errors = super + [empty_vg_error]

        errors.compact
      end

      # Error when the volume group does not containg LVs
      #
      # @return [String, nil] nil if there are logical volumes to delete
      def empty_vg_error
        return nil if device.lvm_lvs.any?

        # TRANSLATORS: Error when trying to delete LVs from an empty VG
        _("The volume group does not contain logical volumes.")
      end

      # @see DeleteDevices#confirm
      #
      # @return [Boolean]
      def confirm
        confirm_recursive_delete(
          device,
          _("Confirm Deleting of Current Devices"),
          _("If you proceed, the following devices will be deleted:"),
          _("Really delete all these devices?")
        )
      end
    end
  end
end
