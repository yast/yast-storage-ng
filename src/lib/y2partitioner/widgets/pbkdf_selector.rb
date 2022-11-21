# Copyright (c) [2021] SUSE LLC
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
require "y2storage/pbkd_function"

module Y2Partitioner
  module Widgets
    # PBKDF for a {Y2Storage::Encryption} device using LUKS2
    class PbkdfSelector < CWM::ComboBox
      # Constructor
      #
      # @param controller [Actions::Controllers::Encryption]
      # @param enable [Boolean] whether the widget should be enabled on init
      def initialize(controller, enable: true)
        super()
        textdomain "storage"

        @controller = controller
        @enable_on_init = enable
      end

      # @macro seeAbstractWidget
      def label
        _("Password-Based Key Derivation &Function (PBKDF)")
      end

      # Sets the initial value
      def init
        enable_on_init ? enable : disable
        self.value = @controller.pbkdf&.value
      end

      # @macro seeItemsSelection
      def items
        Y2Storage::PbkdFunction.all.map { |opt| [opt.value, opt.name] }
      end

      # @macro seeAbstractWidget
      def store
        @controller.pbkdf = Y2Storage::PbkdFunction.find(value)
      end

      private

      # @return [Boolean] whether the widget should be enabled on init
      attr_reader :enable_on_init
    end
  end
end
