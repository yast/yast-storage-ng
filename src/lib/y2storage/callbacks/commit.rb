# Copyright (c) [2017-2020] SUSE LLC
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

require "y2storage/callbacks/libstorage_callback"

module Y2Storage
  module Callbacks
    # Class to implement callbacks used during libstorage-ng commit
    class Commit < Storage::CommitCallbacks
      include LibstorageCallback

      # Constructor
      #
      # @param widget [#add_action]
      def initialize(widget: nil)
        super()

        @widget = widget
      end

      # Updates the widget (if any) with the given message
      def message(message)
        widget&.add_action(message)
      end

      # @see LibstorageCallback#error
      #
      # @return [Boolean]
      def default_answer_to_error
        false
      end

      private

      attr_reader :widget
    end
  end
end
