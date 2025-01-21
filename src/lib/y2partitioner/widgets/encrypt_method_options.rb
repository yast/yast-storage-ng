# Copyright (c) [2019-2025] SUSE LLC
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
require "y2partitioner/widgets/pervasive_key"
require "y2partitioner/widgets/pervasive_key_selector"
require "y2partitioner/widgets/apqn_selector"
require "y2partitioner/widgets/pervasive_key_type_selector"

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
        if select_master_key? && event["ID"] == master_key_widget.widget_id
          full_key_widget.refresh(master_key_widget.value)
          apqn_widget.refresh(master_key_widget.value) if select_apqns?
          key_type_widget.refresh(candidate_apqns.first.name)
        end

        nil
      end

      # @return [Boolean]
      def validate
        validate_secure_key_generation
      end

      # Saves the selected APQNs and key type into the controller
      def store
        controller.apqns = selected_apqns
        controller.secure_key_type = key_type_widget.value
      end

      private

      # @see LuksOptions#widgets
      def widgets
        widgets = super
        return widgets if exist_secure_key?

        if select_master_key?
          widgets << master_key_widget
          widgets << full_key_widget
        end
        widgets << apqn_widget if select_apqns?
        widgets << key_type_widget
        widgets
      end

      # APQNs that can be chosen, based on the master key currently selected (implicitly or
      # explicitly) at the UI
      #
      # @return [Array<Y2Storage::EncryptionProcesses::Apqn>]
      def candidate_apqns
        return apqns_by_key.values.first unless select_master_key?

        apqns_by_key[master_key_widget.value]
      end

      # Set of APQNs selected at the UI (implicitly or explicitly)
      #
      # @return [Array<Y2Storage::EncryptionProcesses::Apqn>]
      def selected_apqns
        candidate = candidate_apqns
        return candidate if candidate.size == 1

        apqn_widget.value.map { |a| controller.find_apqn(a) }.compact
      end

      # Whether there is an secure key for the device
      #
      # @return [Boolean]
      def exist_secure_key?
        !controller.secure_key.nil?
      end

      # Whether the AES master key can be chosen
      #
      # The master key can be chosen when there are several keys available and the device does not
      # have an associated secure key yet.
      #
      # @return [Boolean]
      def select_master_key?
        apqns_by_key.keys.size > 1
      end

      # Whether there is any possibility to define the APQNs
      #
      # @return [Boolean]
      def select_apqns?
        apqns_by_key.any? { |i| i.last.size > 1 }
      end

      # @return [String]
      def initial_key
        @initial_key ||=
          if controller.apqns.empty?
            pervasive_keys.min_by { |k| apqns_by_key[k].first.name }
          else
            find_key_for(controller.apqns.first)
          end
      end

      # Master key configured at the given APQN
      #
      # @param apqn [Y2Storage::EncryptionProcesses::Apqn]
      # @return [String]
      def find_key_for(apqn)
        apqns_by_key.each do |key, apqns|
          return key if apqns.include?(apqn)
        end
      end

      # @return [Array<Y2Storage::EncryptionProcesses::Apqn>]
      def initial_apqns
        @initial_apqns ||=
          if controller.apqns.empty?
            apqns_by_key[initial_key]
          else
            controller.apqns
          end
      end

      # All existing master keys
      #
      # @return [Array<String>]
      def pervasive_keys
        @pervasive_keys ||= apqns_by_key.keys.sort
      end

      def apqns_by_key
        @apqns_by_key ||= controller.online_apqns.group_by(&:master_key_pattern)
      end

      # Widget to allow the master key selection
      #
      # @return [Widgets::PervasiveKeySelector]
      def master_key_widget
        @master_key_widget ||=
          Widgets::PervasiveKeySelector.new(apqns_by_key, initial_key, enable: enable_on_init)
      end

      # Widget to allow the APQNs selection
      #
      # @return [Widgets::ApqnSelector]
      def apqn_widget
        @apqn_widget ||=
          Widgets::ApqnSelector.new(apqns_by_key, initial_key, initial_apqns, enable: enable_on_init)
      end

      # Read-only widget to display the full verification pattern of the chosen master key,
      # if needed
      #
      # @return [Widgets::PervasiveKey]
      def full_key_widget
        @full_key_widget ||= Widgets::PervasiveKey.new(initial_key)
      end

      # Widget to choose the type of CCA key to use (AES Data vs AES Cipher)
      #
      # @return [Widgets::PervasiveKeyTypeSelector]
      def key_type_widget
        @key_type_widget ||= PervasiveKeyTypeSelector.new(
          @controller, initial_apqns.first.name, enable: enable_on_init
        )
      end

      # Checks whether the secure key can be generated
      #
      # An error is reported to the user when the secure key cannot be generated.
      #
      # @return [Boolean]
      def validate_secure_key_generation
        apqns = selected_apqns
        command_error_message = controller.test_secure_key_generation(apqns, key_type_widget.value)
        return true unless command_error_message

        error = _("The secure key cannot be generated.")
        Yast2::Popup.show(error, headline: :error, details: command_error_message)

        false
      end
    end
  end
end
