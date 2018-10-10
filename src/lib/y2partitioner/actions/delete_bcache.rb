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

      # @see DeleteDevice
      def simple_confirm_text
        bcache_cset_note + super
      end

      # @see DeleteDevice
      def recursive_confirm_text_below
        bcache_cset_note + super
      end

      # Note explaining that also bcache cset will be deleted
      #
      # @return [String] empty string if the bcache cset is not going
      #   to be deleted
      def bcache_cset_note
        # no note if there is no bcache cset associated or if cset is shared by more devices
        return "" unless single_bcache_cset?

        _(
          "The selected Bcache is the only one using its caching set.\n" \
          "The caching set will be also deleted.\n\n"
        )
      end

      # Checks if there is only single bcache cset used by this bcache, so it will be delited
      def single_bcache_cset?
        device.bcache_cset && device.bcache_cset.bcaches.size == 1
      end
    end
  end
end
