# Copyright (c) [2024] SUSE LLC
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
require "yast2/popup"
require "y2partitioner/widgets/encrypt_password"
require "y2partitioner/widgets/encrypt_label"
require "y2partitioner/widgets/pbkdf_selector"
require "y2partitioner/widgets/apqn_selector"

module Y2Partitioner
  module Widgets
    # Widget to display BLA
    class PervasiveEncryptionOptions < CWM::ReplacePoint
      # Constructor
      #
      # @param controller [Actions::Controllers::Encryption]
      def initialize(controller)
        super(id: "pervasive_options", widget: empty_widget)
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

      # @return [Boolean]
      def validate
        validate_secure_key_generation
      end

      private

      # @return [Actions::Controllers::Encryption]
      attr_reader :controller

      # Options:
      #  No master key => Is possible to do pervasive encryption?
      #  One master key
      #    One APQN with that key => Nothing to select
      #    Several APQNs with that key => Selecting APQN makes sense
      #  Several master keys
      #    It makes sense to change the key and selecting APQN depends on the whether the key has
      #    several ones
      #
      #
      # Whether it is possible to select APQNs
      #
      # APQNs can be selected when there are more than one APQN available and the device has not have an
      # associated secure key yet.
      #
      # @return [Boolean]
      def select_apqns?
        !exist_secure_key? && several_apqns?
      end

      # Whether it is possible to select the AES master key and associated APQNs
      #
      # APQNs can be selected when there are more than one APQN available and the device has not have an
      # associated secure key yet.
      #
      # @return [Boolean]
      def select_apqns?
        !exist_secure_key? && several_apqns?
      end

      # Whether there is an secure key for the device
      #
      # @return [Boolean]
      def exist_secure_key?
        !controller.secure_key.nil?
      end

      # Whether there are several available APQNs
      #
      # @return [Boolean]
      def several_apqns?
        controller.online_apqns.size > 1
      end
      # Checks whether the secure key can be generated
      #
      # An error is reported to the user when the secure key cannot be generated.
      #
      # @return [Boolean]
      def validate_secure_key_generation
        apqns = select_apqns? ? apqn_widget.value : []

        command_error_message = controller.test_secure_key_generation(apqns: apqns)

        return true unless command_error_message

        error = _("The secure key cannot be generated.\n")

        error += if apqns.size > 1
          _("Make sure that all selected APQNs are configured with the same master key.")
        elsif apqns.size == 1
          _("Make sure that the selected APQN is configured with a master key.")
        else
          _("Make sure that all available APQNs are configured with the same master key.")
        end

        Yast2::Popup.show(error, headline: :error, details: command_error_message)

        false
      end
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
        when :luks1
          LuksOptions.new(controller, enable: enabled?)
        when :luks2
          Luks2Options.new(controller, enable: enabled?)
        when :pervasive_luks2
          PervasiveOptions.new(controller, enable: enabled?)
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
        super()
        textdomain "storage"
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
                "may imply a certain risk of losing data.\n" \
                "\n" \
                "Read the help for more information.")
            )
          )
        )
      end
    end


    # Internal widget to display the pervasive encryption options
    class PervasiveOptions < LuksOptions

      # @see LuksOptions#widgets
      def widgets
        widgets = super
        if select_master_key?
          widgets << master_key_widget
          widgets << apqn_widget if select_apqns?

        widgets
      end

      # Widget to allow the APQNs selection
      #
      # @return [Widgets::ApqnSelector]
      def apqn_widget
        @apqn_widget ||= Widgets::ApqnSelector.new(@controller, enable: enable_on_init)
      end
    end
  end
end
