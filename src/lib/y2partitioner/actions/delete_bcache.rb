# encoding: utf-8

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
require "y2partitioner/actions/delete_device"

module Y2Partitioner
  module Actions
    # Action for deleting a Bcache
    #
    # @see DeleteDevice
    class DeleteBcache < DeleteDevice
      def initialize(*args)
        super
        textdomain "storage"
      end

    private

      # Deletes the indicated Bcache (see {DeleteDevice#device})
      def delete
        log.info "deleting bcache raid #{device}"
        device_graph.remove_bcache(device)
      end

      # Confirmation before performing the delete action
      #
      # @return [Boolean]
      def confirm
        if device.partitions.any?
          confirm_for_partitions
        elsif single_bcache_cset?
          confirm_bcache
        else
          super
        end
      end

      # Confirmation when the device contains partitions
      #
      # @see ConfirmRecursiveDelete#confirm_recursive_delete
      #
      # @return [Boolean]
      def confirm_for_partitions
        confirm_recursive_delete(
          device,
          _("Confirm Deleting Bcache with its Devices"),
          bcache_cset_note + format(_("The selected Bcache has associated devices.\n" \
            "To keep the system in a consistent state, the following\n" \
            "associated devices will be deleted:")),
          # TRANSLATORS: bcache is the name of the bcache to be deleted (e.g., /dev/bcache0)
          format(_("Delete bcache \"%{bcache}\" and the affected devices?"), bcache: device.name)
        )
      end

      # notes that also bcache cset will be deleted
      def bcache_cset_note
        # no note if there is no bcache cset associated or if cset is shared by more devices
        return "" unless single_bcache_cset?

        _("The selected Bcache is only user of the caching set. The caching set will be also deleted.") +
          "\n"
      end

      # Checks if there is only single bcache cset used by this bcache, so it will be delited
      def single_bcache_cset?
        device.bcache_cset && device.bcache_cset.bcaches.size == 1
      end

      # Confirmation when the device does not contain partitions,
      # but result in deleting also bcache_cset
      def confirm_bcache
        # TRANSLATORS %s is the name of the device to be deleted (e.g., /dev/bcache0)
        message = format(_("Really delete %s?"), device.name)

        result = Yast2::Popup.show(bcache_cset_note + message, buttons: :yes_no)
        result == :yes
      end
    end
  end
end
