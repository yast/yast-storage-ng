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
require "y2storage"
require "y2partitioner/widgets/encrypt_type"
require "y2partitioner/widgets/encrypt_password"

module Y2Partitioner
  module Widgets
    class EncryptionOptions < CWM::CustomWidget
      def initialize(controller)
        textdomain "storage"

        @controller = controller
        self.handle_all_events = true
      end

      def contents
        HVSquash(
          VBox(
            Left(type_widget),
            password_widget
          )
        )
      end

      def handle(event)
        return nil unless display_type?

        if event["ID"] === type_widget.event_id
          controller.encrypt_type = type_widget.value
          password_widget.refresh
        end

        nil
      end

      private

      attr_reader :controller

      def display_type?
        controller.blk_device.swap?
      end

      def type_widget
        @type_widget ||=
          if display_type?
            Widgets::EncryptType.new(controller)
          else
            Empty()
          end
      end

      def password_widget
        @password_widget ||= Widgets::EncryptPassword.new(controller)
      end
    end
  end
end
