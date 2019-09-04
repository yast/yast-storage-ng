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
require "y2storage/encryption_type"

module Y2Partitioner
  module Widgets
    class EncryptType < CWM::ComboBox
      def initialize(controller)
        textdomain "storage"

        @controller = controller
      end

      def init
        self.value = controller.encrypt_type
      end

      # @macro seeAbstractWidget
      def opt
        [:hstretch, :notify]
      end

      def label
        _("Encryption type")
      end

      def items
        controller.encrypt_types.map do |type|
          # FIXME
          if type.is?(:twofish)
            [type.to_i, _("Random password")]
          else
            [type.to_i, type.to_human_string]
          end
        end
      end

      def value
        Y2Storage::EncryptionType.find(super)
      end

      def value=(v)
        super(v.to_i)
      end

      # @macro seeAbstractWidget
      def store
        controller.encrypt_type = value
      end

      private

      attr_reader :controller
    end
  end
end
