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
    # Action for deleting an LVM volume group
    #
    # @see DeleteDevice
    class DeleteLvmVg < DeleteDevice
      def initialize(*args)
        super
        textdomain "storage"
      end

      # Confirmation message before performing the delete action
      def confirm
        if device.lvm_lvs.empty?
          super
        else
          confirm_for_used
        end
      end

      # Deletes the indicated LVM volume group (see {DeleteDevice#device})
      def delete
        log.info "deleting vg #{device}"
        device_graph.remove_lvm_vg(device)
      end

    private

      # Confirmation when the device contains logical volumes
      #
      # @see DeleteDevice#dependent_devices
      # @see DeleteDevice#confirm_recursive_delete
      def confirm_for_used
        confirm_recursive_delete(
          dependent_devices,
          _("Confirm Deleting of Volume Group"),
          # TRANSLATORS: %s is the name of the volume group (e.g. "system")
          format(_("The volume group \"%s\" contains at least one logical volume.\n" \
            "If you proceed, the following volumes will be unmounted (if mounted)\n" \
            "and deleted:"), device.vg_name),
          # TRANSLATORS: %s is the name of the volume group (e.g. "system")
          format(
            _("Really delete volume group \"%s\" and all related logical volumes?"), device.vg_name
          )
        )
      end
    end
  end
end
