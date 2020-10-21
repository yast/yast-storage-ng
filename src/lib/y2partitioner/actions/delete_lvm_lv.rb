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
require "y2partitioner/ui_state"
require "y2partitioner/actions/delete_device"

module Y2Partitioner
  module Actions
    # Action for deleting a logical volume
    #
    # @see DeleteDevice
    class DeleteLvmLv < DeleteDevice
      def initialize(*args)
        super
        textdomain "storage"
      end

      private

      # Deletes the indicated logical volume (see {DeleteDevice#device})
      #
      # @note When the device is a thin pool, all thin volumes over the pool
      #   are automatically deleted.
      def delete
        log.info "deleting logical volume #{device}"
        vg = device.lvm_vg
        vg.delete_lvm_lv(device)
        UIState.instance.select_row(vg.sid)
      end

      # Confirmation before performing the delete action
      #
      # @return [Boolean]
      def confirm
        affected_volumes? ? confirm_for_used_volume : super
      end

      # Whether deleting the device would result in other logical volumes also
      # been deleted
      #
      # @return [Boolean] true if it is an used volume; false otherwise.
      def affected_volumes?
        device.descendants(Y2Storage::View::REMOVE).any? { |dev| dev.is?(:lvm_lv) }
      end

      # Confirmation when deleting the device affects other volumes
      #
      # @see ConfirmRecursiveDelete#confirm_recursive_delete
      #
      # @return [Boolean]
      def confirm_for_used_volume
        title =
          if device.lv_type.is?(:thin_pool)
            _("Confirm Deleting of LVM Thin Pool")
          else
            _("Confirm Deleting of LVM Logical Volume")
          end

        confirm_recursive_delete(
          device,
          title,
          # TRANSLATORS: Confirmation message when a LVM logical volume is going to be deleted,
          # where %{name} is replaced by the name of the volume (e.g., /dev/system/pool)
          format(
            _("The volume %{name} is used by at least one another volume.\n" \
              "If you proceed, the following volumes will be unmounted (if mounted)\n" \
              "and deleted:"),
            name: device.name
          ),
          # TRANSLATORS: %{name} is replaced by the name of the logical volume (e.g., /dev/system/pool)
          format(
            _("Really delete \"%{name}\" and all related volumes?"),
            name: device.name
          )
        )
      end
    end
  end
end
