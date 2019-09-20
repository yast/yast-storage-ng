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
require "y2partitioner/widgets/encrypt_method"
require "y2partitioner/widgets/encrypt_method_options"
require "y2partitioner/widgets/helpers"

module Y2Partitioner
  module Widgets
    # Widget to set the encryption method and options
    class Encrypt < CWM::CustomWidget
      include Helpers

      # Constructor
      #
      # @param controller [Actions::Controllers::Encryption]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
        self.handle_all_events = true
      end

      # @macro seeAbstractWidget
      def init
        encrypt_method_options_widget.refresh(controller.method)
      end

      # @macro seeCustomWidget
      def contents
        HVSquash(
          HBox(
            Id(widget_id),
            HWeight(
              33,
              VBox(*add_spacing(left_align(widgets), VSpacing(1)))
            )
          )
        )
      end

      # Handles the events comming from UI, forcing to refresh the encrypt
      # options each time the encryption method is changed.
      #
      # @macro seeCustomWidget
      def handle(event)
        if event["ID"] == encrypt_method_widget.widget_id
          encrypt_method_options_widget.refresh(encrypt_method_widget.value)
        end

        nil
      end

      # @macro seeCustomWidget
      def help
        format(
          _("<p>%{header}</p><ul>%{content}</ul>"),
          header:  help_header,
          content: help_content
        )
      end

      private

      # @return [Actions::Controllers::Encryption] controller for the encryption device
      attr_reader :controller

      # Widgets to show
      #
      # @return [Array<Widgets>]
      def widgets
        widgets = []
        widgets << encrypt_method_widget if display_encrypt_method?
        widgets << encrypt_method_options_widget

        widgets
      end

      # Returns the widget to select the encryption method
      #
      # @return [Widgets::EncryptMethod]
      def encrypt_method_widget
        @encrypt_method_widget ||= EncryptMethod.new(controller)
      end

      # Returns the widget in charge of displaying the options for the selected
      # encryption method
      #
      # @return [Widgets::EncryptMethodOptions]
      def encrypt_method_options_widget
        @encrypt_method_options_widget ||= EncryptMethodOptions.new(controller)
      end

      # Whether the encryption method widget should be displayed
      #
      # @return [Boolean] true if there is more than one method available; false otherwise
      def display_encrypt_method?
        controller.several_encrypt_methods?
      end

      # The introductory help text
      #
      # @return [String]
      def help_header
        if controller.several_encrypt_methods?
          _("The following encryption methods can be chosen:")
        else
          _("The following encryption method will be used:")
        end
      end

      # Help texts for available encryption methods
      #
      # @return [String]
      def help_content
        texts = controller.methods.map do |m|
          text = send("help_for_#{m.id}", m)
          "<li>#{text}</li>"
        end

        texts.join
      end

      # Help text for the Random Swap encryption method
      #
      # @return [String]
      def help_for_random_swap(encrypt_method)
        format(
          _("<p><b>%{label}</b>: this encryption method uses randomly generated keys at boot and it " \
            "will not support Hibernation to hard disk. The swap device is re-encrypted during every " \
            "boot, and its previous content is destroyed. You should disable Hibernation through your " \
            "respective DE Power Management Utility and set it to Shutdown on Critical to avoid Data " \
            "Loss!</p>" \
            "<p>Please, make sure your swap device is mounted by a stable name that is not subject to " \
            "change on every reboot. For example, for a swap partition use the udev device id instead " \
            "of the partition device name. Otherwise a wrong device could be encrypted instead of " \
            "your swap! In that regard, note both the file system label and the UUID change every " \
            "time the swap is re-encrypted, so they are not valid options to mount a " \
            "randomly encrypted swap device.</p>"),
          label: encrypt_method.to_human_string
        )
      end

      # Help text for the Regular Luks1 encryption method
      #
      # @return [String]
      def help_for_luks1(encrypt_method)
        format(
          _("<p><b>%{label}</b>: allows to encrypt the device using LUKS1 " \
            "(Linux Unified Key Setup). You have to provide the encryption password.</p>"),
          label: encrypt_method.to_human_string
        )
      end

      # Help text for the  encryption method
      #
      # @return [String]
      def help_for_pervasive_luks2(encrypt_method)
        format(
          _("<p><b>%{label}</b>: TODO</p>"),
          label: encrypt_method.to_human_string
        )
      end
    end
  end
end
