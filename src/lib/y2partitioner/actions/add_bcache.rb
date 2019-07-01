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
require "y2partitioner/actions/base"
require "y2partitioner/actions/controllers/bcache"
require "y2partitioner/dialogs/bcache"
require "y2partitioner/ui_state"

module Y2Partitioner
  module Actions
    # Action for adding a bcache device, see {Actions::Base}
    class AddBcache < Base
      def initialize
        super

        textdomain "storage"

        @controller = Controllers::Bcache.new
      end

      private

      # @return [Controllers::Bcache]
      attr_reader :controller

      # List of errors that avoid to create a bcache
      #
      # @see Actions::Base#errors
      #
      # @return [Array<String>]
      def errors
        (super + [no_backing_devices_error]).compact
      end

      # Error when there is no suitable backing devices for creating a bcache
      #
      # @return [String, nil] nil if there are suitable backing devices.
      def no_backing_devices_error
        return nil if suitable_backing_devices?

        # TRANSLATORS: Error message.
        _("There are not enough suitable unused devices to create a bcache.")
      end

      # Opens a dialog to create a bcache
      #
      # The bcache is created only if the dialog is accepted.
      #
      # @see Actions::Base#perform_action
      def perform_action
        dialog = Dialogs::Bcache.new(controller)

        return unless dialog.run == :next

        controller.create_bcache(dialog.backing_device, dialog.caching_device, dialog.options)
        UIState.instance.select_row(controller.bcache)
      end

      # Whether there is suitable backing devices
      #
      # @return [Boolean]
      def suitable_backing_devices?
        controller.suitable_backing_devices.any?
      end
    end
  end
end
