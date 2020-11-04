# Copyright (c) [2019-2020] SUSE LLC
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
require "yast/i18n"
require "yast2/popup"
require "y2partitioner/ui_state"
require "abstract_method"

module Y2Partitioner
  module Actions
    # Base class for actions that can be performed by the Expert Partitioner
    #
    # This base class is mainly intended to one-step actions. For more complex actions,
    # see {TransactionWizard}.
    class Base
      include Yast::I18n

      def initialize
        textdomain "storage"
      end

      # Runs the action
      #
      # @return [Symbol, nil]
      def run
        return :back unless run?

        UIState.instance.save_extra_info

        perform_action
      end

      private

      # Performs the action, see {#run}
      #
      # This method should be defined by derived classes.
      #
      # @return [Symbol, nil] nil when the action is canceled
      abstract_method :perform_action

      # Checks whether the action can be performed
      #
      # @return [Boolean]
      def run?
        validate
      end

      # Validations before performing the action
      #
      # @note The action can be performed if there are no errors (see #errors).
      #   Only the first error is shown.
      #
      # @return [Boolean]
      def validate
        current_errors = errors
        return true if current_errors.empty?

        Yast2::Popup.show(current_errors.first, headline: :error)
        false
      end

      # List of errors that avoid to perform the action
      #
      # @return [Array<String>] translated error messages
      def errors
        []
      end
    end
  end
end
