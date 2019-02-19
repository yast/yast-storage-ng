# encoding: utf-8

# Copyright (c) [2018-2019] SUSE LLC
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
require "y2partitioner/actions/controllers/bcache"
require "y2partitioner/ui_state"

module Y2Partitioner
  module Actions
    # Action for deleting a Bcache, see {Actions::DeleteBcache}
    class DeleteBcache < DeleteDevice
      # Constructor
      #
      # @param bcache [Y2Storage::Bcache]
      def initialize(bcache)
        super

        textdomain "storage"

        @bcache_controller = Controllers::Bcache.new(bcache)
        UIState.instance.select_row(bcache)
      end

    private

      # @return [Controllers::Bcache]
      attr_reader :bcache_controller

      # @see Actions::Base#errors
      def errors
        (super + [flash_only_error, unsafe_detach_error]).compact
      end

      # Error when the bcache is Flash-only
      #
      # @return [String, nil] nil if the bcache is not Flash-only.
      def flash_only_error
        return nil unless flash_only_bcache?

        # TRANSLATORS: error message, %{name} is replaced by a bcache name (e.g., /dev/bcache0)
        format(
          _("The device %{name} is a Flash-only Bcache. Deleting this kind of devices\n" \
            "is not supported yet."),
          name: bcache_controller.bcache.name
        )
      end

      # Error when the caching set cannot be detached safely
      #
      # @see doc/bcache.md
      #
      # @return [String, nil] nil if detach is safe
      def unsafe_detach_error
        return nil if safe_detach_bcache?

        # TRANSLATORS: Error message when detach is not a safe action
        _(
          "The bcache cannot be deleted because it shares its cache set with other devices.\n" \
          "Deleting it without detaching the device first can result in unreachable space.\n" \
          "Unfortunately detaching can take a very long time in some situations."
        )
      end

      # Deletes the indicated Bcache (see {Actions::DeleteDevice#device})
      def delete
        bcache_controller.delete_bcache
      end

      # @see DeleteDevice
      def simple_confirm_text
        bcache_cset_note + super
      end

      # @see DeleteDevice
      def recursive_confirm_text_below
        bcache_cset_note + super
      end

      # Note explaining that the caching set will be deleted
      #
      # @return [String] empty string if the caching set is not going to be deleted.
      def bcache_cset_note
        # no note if there is no bcache cset associated or if cset is shared by more devices
        return "" unless bcache_controller.single_committed_bcache_cset?

        _(
          "The selected Bcache is the only one using its caching set.\n" \
          "The caching set will be also deleted.\n\n"
        )
      end

      # Whether the bcache is Flash-only
      #
      # @return [Boolean]
      def flash_only_bcache?
        bcache_controller.bcache.flash_only?
      end

      # Whether the caching set can be safely detached
      #
      # @return [Boolean]
      def safe_detach_bcache?
        !bcache_controller.committed_bcache? ||
          !bcache_controller.committed_bcache_cset? ||
          bcache_controller.single_committed_bcache_cset?
      end
    end
  end
end
