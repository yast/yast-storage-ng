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
        Yast::Popup.YesNo(
          # TRANSLATORS %s is the name of the logical volume to be deleted
          format(_("Remove the logical volume %s?"), device.name)
        )
      end

      # Deletes the indicated logical volume (see {DeleteDevice#device})
      def delete
        log.info "deleting logical volume #{device}"
        vg = device.lvm_vg
        vg.delete_lvm_lv(device)
      end
    end
  end
end
