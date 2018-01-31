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
require "y2partitioner/actions/delete_device"

module Y2Partitioner
  module Actions
    # Action for deleting a logical volume
    #
    # @see DeleteDevice
    class DeleteLvmLv < DeleteDevice
      # Confirmation message before performing the delete action
      def confirm
        used_pool? ? confirm_for_used_pool : confirm_for_lv
      end

      # Deletes the indicated logical volume (see {DeleteDevice#device})
      #
      # @note When the device is a thin pool, all thin volumes over the pool
      #   are automatically deleted.
      def delete
        log.info "deleting logical volume #{device}"
        vg = device.lvm_vg
        vg.delete_lvm_lv(device)
      end

    private

      # Whether the device is a LVM thin pool and it contains any thin volume
      #
      # @return [Boolean] true if it is an used pool; false otherwise.
      def used_pool?
        device.lv_type.is?(:thin_pool) && !device.lvm_lvs.empty?
      end

      # Confirmation when the device is not a LVM thin pool, or the pool is not used yet
      def confirm_for_lv
        Yast::Popup.YesNo(
          # TRANSLATORS: Confirmation message when a LVM logical volume is going to be deleted,
          # where %{name} is replaced by the name of the logical volume (e.g., /dev/system/lv1)
          format(_("Remove the logical volume %{name}?"), name: device.name)
        )
      end

      # Confirmation when the device is a LVM thin pool and there is any thin volume over it
      #
      # @see DeleteDevice#dependent_devices
      # @see DeleteDevice#confirm_recursive_delete
      def confirm_for_used_pool
        confirm_recursive_delete(
          dependent_devices,
          _("Confirm Deleting of LVM Thin Pool"),
          # TRANSLATORS: Confirmation message when a LVM thin pool is going to be deleted,
          # where %{name} is replaced by the name of the thin pool (e.g., /dev/system/pool)
          format(
            _("The thin pool %{name} is used by at least one thin volume.\n" \
              "If you proceed, the following thin volumes will be unmounted (if mounted)\n" \
              "and deleted:"),
            name: device.name
          ),
          # TRANSLATORS: %{name} is replaced by the name of the thin pool (e.g., /dev/system/pool)
          format(
            _("Really delete the thin pool \"%{name}\" and all related thin volumes?"),
            name: device.name
          )
        )
      end
    end
  end
end
