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
require "y2partitioner/widgets/encrypt_password"

module Y2Partitioner
  module Widgets
    class EncryptTypeOptions < CWM::ReplacePoint
      def initialize(controller)
        super(id: "encrypt_options", widget: empty_widget)

        @controller = controller
      end

      def refresh(encrypt_type)
        replace(options_for(encrypt_type))
      end

      private

      attr_reader :controller

      def empty_widget
        @empty_widget ||= CWM::Empty.new("__empty__")
      end

      def options_for(encrypt_type)
        # FIXME
        if encrypt_type.is?(:twofish)
          PlainOptions.new(controller)
        elsif encrypt_type.is?(:luks1)
          Luks1Options.new(controller)
        end
      end
    end

    class PlainOptions < CWM::CustomWidget
      def initialize(controller)
        @controller = controller
      end

      def contents
        VBox(
          Left(
            Label(
              _("Be careful: the system cannot hibernate when\n" \
                "encrypting swap with random password.")
            )
          )
        )
      end
    end

    class Luks1Options < CWM::CustomWidget
      def initialize(controller)
        @controller = controller
      end

      def contents
        VBox(Widgets::EncryptPassword.new(@controller))
      end
    end
  end
end
