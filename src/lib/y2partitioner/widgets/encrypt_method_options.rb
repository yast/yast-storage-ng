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
    # Widget to display the available options for a given encryption method
    class EncryptMethodOptions < CWM::ReplacePoint
      # Constructor
      #
      # @param controller [Actions::Controllers::Encryption]
      def initialize(controller)
        super(id: "encrypt_options", widget: empty_widget)
        textdomain "storage"

        @controller = controller
      end

      # Redraws the widget to show the options for given encryption method
      #
      # @param encrypt_method [YStorage::EncryptionMethod]
      def refresh(encrypt_method)
        replace(options_for(encrypt_method))
      end

      # @macro seeAbstractWidget
      #
      # Note its internal widget needs to be enabled.
      def enable
        super

        @widget.enable
      end

      # @macro seeAbstractWidget
      #
      # Note its internal widget needs to be disabled.
      def disable
        super

        @widget.disable
      end

      private

      # @return [Actions::Controllers::Encryption]
      attr_reader :controller

      # @return [CWM::Empty] an empty widget
      def empty_widget
        @empty_widget ||= CWM::Empty.new("__empty__")
      end

      # @return [CWM::CustomWidget] a widget containing the options for the
      # given encryption method
      def options_for(encrypt_method)
        case encrypt_method.to_sym
        when :random_swap, :protected_swap, :secure_swap
          SwapOptions.new(controller)
        when :luks1, :pervasive_luks2
          LuksOptions.new(controller, enable: enabled?)
        end
      end
    end

    # Internal widget to display the options for a swap encryption method
    #
    # Since there is no available options yet, it is being used just to display
    # a warning message to the user.
    class SwapOptions < CWM::CustomWidget
      # Constructor
      #
      # @param controller [Actions::Controllers::Encryption]
      def initialize(controller)
        @controller = controller
      end

      # @macro seeCustomWidget
      def contents
        VBox(
          Left(
            Label(
              _("Be careful: the system cannot hibernate when\n" \
                "encrypting swap with randomly generated keys.\n" \
                "\n" \
                "Moreover, using this with some kinds of devices\n" \
                "may imply a certain risk of loosing data.\n" \
                "\n" \
                "Please, read Help for more information.")
            )
          )
        )
      end
    end

    # Internal widget to display the Luks encryption options
    class LuksOptions < CWM::CustomWidget
      # Constructor
      #
      # @param controller [Actions::Controllers::Encryption]
      # @param enable [Boolean] whether the widget should be enabled on init
      def initialize(controller, enable: true)
        @controller = controller
        @enable_on_init = enable
      end

      # @macro seeCustomWidget
      def contents
        VBox(password_widget)
      end

      # @macro seeAbstractWidget
      #
      # Note its internal widget needs to be enabled.
      def enable
        super

        password_widget.enable
      end

      # @macro seeAbstractWidget
      #
      # Note its internal widget needs to be disabled.
      def disable
        super

        password_widget.disable
      end

      private

      # Whether the widget is enabled on init
      #
      # @return [Boolean]
      attr_reader :enable_on_init

      # Widget to enter the password
      #
      # @return [Widgets::EncryptPassword]
      def password_widget
        @password_widget ||= Widgets::EncryptPassword.new(@controller, enable: enable_on_init)
      end
    end
  end
end
