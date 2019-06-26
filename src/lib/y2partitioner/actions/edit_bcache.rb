# Copyright (c) [2019] SUSE LLC
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
require "y2partitioner/actions/base"
require "y2partitioner/actions/controllers/bcache"
require "y2partitioner/dialogs/bcache"
require "y2partitioner/ui_state"

module Y2Partitioner
  module Actions
    # Action for editing a bcache device, see {Actions::Base}
    class EditBcache < Base
      # Constructor
      #
      # @param bcache [Y2Storage::Bcache]
      def initialize(bcache)
        super()

        textdomain "storage"

        @controller = Controllers::Bcache.new(bcache)
        UIState.instance.select_row(bcache)
      end

      private

      # @return [Controllers::Bcache]
      attr_reader :controller

      # List of errors that avoid to edit a bcache
      #
      # @see Actions::Base#errors
      #
      # @return [Array<String>]
      def errors
        (super + [flash_only_error, non_editable_error]).compact
      end

      # Error when the bcache is Flash-only
      #
      # @return [String, nil] nil if the bcache is not Flash-only.
      def flash_only_error
        return nil unless flash_only_bcache?

        # TRANSLATORS: error message, %{name} is replaced by a bcache name (e.g., /dev/bcache0)
        format(
          _("The device %{name} is a flash-only bcache and its caching cannot be modified."),
          name: controller.bcache.name
        )
      end

      # Error when the caching device cannot be modified, see {#editable_bcache_cset?}
      #
      # @return [String, nil] nil if the caching device can be modified.
      def non_editable_error
        return nil if editable_bcache_cset?

        # TRANSLATORS: error message, %{name} is replaced by a bcache name (e.g., /dev/bcache0)
        format(
          _("The bcache %{name} is already created on disk. Such device cannot be modified\n" \
            "because that might imply a detaching operation. Unfortunately detaching can take\n" \
            "a very long time in some situations."),
          name: controller.bcache.name
        )
      end

      # Opens a dialog to edit a bcache
      #
      # The bcache is updated only if the dialog is accepted.
      #
      # @see Actions::Base#perform_action
      def perform_action
        dialog = Dialogs::Bcache.new(controller)

        return unless dialog.run == :next

        controller.update_bcache(dialog.caching_device, dialog.options)
      end

      # Whether the bcache is Flash-only
      #
      # @return [Boolean]
      def flash_only_bcache?
        controller.bcache.flash_only?
      end

      # Whether the caching set can be modified
      #
      # @return [Boolean]
      def editable_bcache_cset?
        !controller.committed_bcache? || !controller.committed_bcache_cset?
      end
    end
  end
end
