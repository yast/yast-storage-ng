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
require "cwm"
require "y2storage/encryption_method"

module Y2Partitioner
  module Widgets
    # Widget making possible to select an encryption method
    class EncryptMethod < CWM::ComboBox
      # Constructor
      #
      # @param controller [Actions::Controllers::Encryption]
      def initialize(controller)
        super()
        textdomain "storage"

        @controller = controller
      end

      # Sets the initial value
      def init
        self.value = controller.method
      end

      # @macro seeAbstractWidget
      def opt
        [:hstretch, :notify]
      end

      # @macro seeAbstractWidget
      def label
        _("Encryption method")
      end

      # @macro seeItemsSelection
      def items
        controller.methods.map { |m| [m.to_sym, m.to_human_string] }
      end

      # Selected encryption method
      #
      # @return [Y2Storage::EncryptionMethod]
      def value
        Y2Storage::EncryptionMethod.find(super)
      end

      # Setter for the value of the widget
      #
      # @param new_value [Symbol, String] the id of the desired encryption method
      def value=(new_value)
        super(new_value.to_sym)
      end

      # @macro seeAbstractWidget
      def store
        controller.method = value
      end

      private

      # @return [Actions::Controllers::Encryption] controller for the encryption device
      attr_reader :controller
    end
  end
end
