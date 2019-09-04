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
require "y2partitioner/widgets/encrypt_type"
require "y2partitioner/widgets/encrypt_type_options"
require "y2partitioner/widgets/helpers"

module Y2Partitioner
  module Widgets
    class Encrypt < CWM::CustomWidget
      include Helpers

      def initialize(controller)
        textdomain "storage"

        @controller = controller
        self.handle_all_events = true
      end

      def contents
        HVSquash(
          HBox(
            HWeight(33,
              VBox(*add_spacing(left_align(widgets), VSpacing(1)))
            )
          )
        )
      end

      def init
        encrypt_type_options_widget.refresh(controller.encrypt_type)
      end

      def handle(event)
        if event["ID"] == encrypt_type_widget.widget_id
          encrypt_type_options_widget.refresh(encrypt_type_widget.value)
        end

        nil
      end

      private

      attr_reader :controller

      def widgets
        widgets = []
        widgets << encrypt_type_widget if display_encrypt_type?
        widgets << encrypt_type_options_widget

        widgets
      end

      def encrypt_type_widget
        @encrypt_type_widget ||= EncryptType.new(controller)
      end

      def encrypt_type_options_widget
        @encrypt_type_options_widget ||= EncryptTypeOptions.new(controller)
      end

      def display_encrypt_type?
        controller.encrypt_types.size > 1
      end
    end
  end
end
