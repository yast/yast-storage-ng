# Copyright (c) [2020] SUSE LLC
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

require "yast2/popup"
require "cwm"
require "y2partitioner/actions/controllers/encryption"

module Y2Partitioner
  module Widgets
    # Widget to select APQNs for generating a new secure key for pervasive encryption
    class ApqnSelector < CWM::MultiSelectionBox
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

      # @return [String]
      def label
        _("Available APQNs:")
      end

      # @macro seeAbstractWidget
      def init
        enable_on_init ? enable : disable
        self.value = controller.apqns
      end

      # @return [Array<String, String>]
      def items
        controller.online_apqns.map { |d| [d.name, "#{d.name} - #{d.aes_master_key}"] }
      end

      # All selected APQNs
      #
      # @return [Array<Y2Storage::EncryptionProcesses::Apqn>]
      def value
        super.map { |d| controller.find_apqn(d) }.compact
      end

      # Sets selected APQNs
      #
      # @param apqns [Array<Y2Storage::EncryptionProcesses::Apqn>]
      def value=(apqns)
        super(apqns.map(&:name))
      end

      # Saves the selected APQNs into the controller
      def store
        controller.apqns = value
      end

      private

      # @return [Actions::Controllers::Encryption]
      attr_reader :controller

      # @return [Boolean]
      attr_reader :enable_on_init
    end
  end
end
