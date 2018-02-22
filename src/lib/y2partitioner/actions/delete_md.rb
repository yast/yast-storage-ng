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
    # Action for deleting a Md Raid
    #
    # @see DeleteDevice
    class DeleteMd < DeleteDevice
      def initialize(*args)
        super
        textdomain "storage"
      end

      # Confirmation message before performing the delete action
      def confirm
        if used_by_lvm?
          confirm_for_used_by_lvm
        else
          super
        end
      end

      # Deletes the indicated md raid (see {DeleteDevice#device})
      def delete
        log.info "deleting md raid #{device}"
        device_graph.remove_md(device)
      end

    private

      # Confirmation when the device belongs to a volume group
      #
      # @see DeleteDevice#dependent_devices
      # @see DeleteDevice#confirm_recursive_delete
      # @see DeleteDevice#lvm_vg
      def confirm_for_used_by_lvm
        confirm_recursive_delete(
          dependent_devices,
          _("Confirm Deleting RAID Used by LVM"),
          # TRANSLATORS: name is the name of the volume group that the md raid
          #   belongs to (e.g., /dev/system)
          format(_("The selected RAID is used by volume group \"%{name}\".\n" \
            "To keep the system in a consistent state, the following volume group\n" \
            "and its logical volumes will be deleted:"), name: lvm_vg.name),
          # TRANSLATORS: md is the name of the md raid to be deleted (e.g., /dev/md/md1),
          #   and vg is the name of the volume group to be deleted (e.g., /dev/system)
          format(_("Delete RAID \"%{md}\" and volume group \"%{lvm_vg}\"?"),
            md: device.name, lvm_vg: lvm_vg.name)
        )
      end
    end
  end
end
