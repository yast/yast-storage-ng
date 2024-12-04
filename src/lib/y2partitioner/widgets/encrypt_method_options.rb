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
require "cwm"
require "yast2/popup"
require "y2partitioner/widgets/encrypt_password"
require "y2partitioner/widgets/encrypt_label"
require "y2partitioner/widgets/pbkdf_selector"
require "y2partitioner/widgets/pervasive_key_selector"
require "y2partitioner/widgets/apqn_selector"

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

    # Internal widget to display the Luks encryption options
    class LuksOptions < CWM::CustomWidget
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

      # @macro seeCustomWidget
      def contents
        VBox(*widgets)
      end

      # @macro seeAbstractWidget
      #
      # Note its internal widgets need to be enabled.
      def enable
        super

        widgets.map(&:enable)
      end

      # @macro seeAbstractWidget
      #
      # Note its internal widgets need to be disabled.
      def disable
        super

        widgets.map(&:disable)
      end

      private

      # @return [Actions::Controllers::Encryption]
      attr_reader :controller

      # Whether the widget is enabled on init
      #
      # @return [Boolean]
      attr_reader :enable_on_init

      # Widgets to show
      #
      # @return [Array<CWM::AbstractWidget>]
      def widgets
        [password_widget]
      end

      # Widget to enter the password
      #
      # @return [Widgets::EncryptPassword]
      def password_widget
        @password_widget ||= Widgets::EncryptPassword.new(@controller, enable: enable_on_init)
      end
    end

    # Internal widget to display the LUKS2 encryption options
    class Luks2Options < LuksOptions
      private

      # @see LuksOptions#widgets
      def widgets
        super.concat([pbkdf_widget, label_widget])
      end

      # Widget to set the password-based key derivation function
      #
      # @return [Widgets::EncryptPbkdf]
      def pbkdf_widget
        @pbkdf_widget ||= Widgets::PbkdfSelector.new(@controller, enable: enable_on_init)
      end

      # Widget to set the label of the LUKS2 device
      #
      # @return [Widgets::EncryptLabel]
      def label_widget
        @label_widget ||= Widgets::EncryptLabel.new(@controller, enable: enable_on_init)
      end
    end

    # Internal widget to display the pervasive encryption options
    class PervasiveOptions < LuksOptions
      def initialize(controller, enable: true)
        super
        textdomain "storage"

        self.handle_all_events = true
      end

      # Handles the events coming from UI, forcing to refresh the encrypt
      # options each time the encryption method is changed.
      #
      # @macro seeCustomWidget
      def handle(event)
        if select_master_key? && select_apqns? && event["ID"] == master_key_widget.widget_id
          apqn_widget.refresh(master_key_widget.value)
        end

        nil
      end

      # @return [Boolean]
      def validate
        validate_secure_key_generation
      end

      # Saves the selected APQNs into the controller
      def store
        controller.apqns = selected_apqns
      end

      private
      
      def selected_apqns
        candidate_apqns =
          if select_master_key?
            apqns_by_key[master_key_widget.value]
          else
            apqns_by_key.values.first
          end

        if candidate_apqns.size > 1
          # TODO: query_widget
        else
          candidate_apqns.first
        end
      end

      # @see LuksOptions#widgets
      def widgets
        widgets = super
        widgets << master_key_widget if select_master_key?
        widgets << apqn_widget if select_apqns?

        widgets
      end

      # Whether the AES master key can be chosen
      #
      # The master key can be chosen when there are several keys available and the device does not
      # have an associated secure key yet.
      #
      # @return [Boolean]
      def select_master_key?
        !exist_secure_key? && pervasive_keys.size > 1
      end

      # Whether there is any possibility to define the APQNs
      #
      # @return [Boolean]
      def select_apqns?
        !exist_secure_key? && apqns_by_key.any? { |i| i.last.size > 1 }
      end

      # Whether there is an secure key for the device
      #
      # @return [Boolean]
      def exist_secure_key?
        !controller.secure_key.nil?
      end

      def apqns_by_key
        @apqns_by_key ||= @controller.online_apqns.group_by(&:aes_master_key)
      end

      def pervasive_keys
        @pervasive_keys ||= apqns_by_key.keys.sort
      end

      def initial_key
        @initial_key ||=
          if @controller.apqns.empty?
            pervasive_keys.first
          else
            find_key_for(@controller.apqns.first)
          end
      end

      def find_key_for(apqn)
        apqns_by_key.each do |key, apqns|
          return key if apqns.include?(apqn)
        end
      end

      def initial_apqns
        @initial_apqns ||=
          if @controller.apqns.empty?
            apqns_by_key[initial_key]
          else
            @controller.apqns
          end
      end

      def master_key_widget
        @master_key_widget ||= Widgets::PervasiveKeySelector.new(apqns_by_key, initial_key, enable: enable_on_init)
      end

      # Widget to allow the APQNs selection
      #
      # @return [Widgets::ApqnSelector]
      def apqn_widget
        @apqn_widget ||= Widgets::ApqnSelector.new(apqns_by_key, initial_key, initial_apqns, enable: enable_on_init)
      end

      # Checks whether the secure key can be generated
      #
      # An error is reported to the user when the secure key cannot be generated.
      #
      # @return [Boolean]
      def validate_secure_key_generation
        # TODO: revisar esto. Seguramente la lógica vaya ahora en el controlador
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
    end
  end
end
