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
        super()
        textdomain "storage"

        @controller = controller
        self.handle_all_events = true
      end

      # @macro seeAbstractWidget
      def init
        encrypt_method_options_widget.refresh(controller.method)
      end

      # @macro seeAbstractWidget
      #
      # Note that "children" widgets need to be enabled.
      def enable
        super

        widgets.map(&:enable)
      end

      # @macro seeAbstractWidget
      #
      # Note that "children" widgets need to be disabled.
      def disable
        super

        widgets.map(&:disable)
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

      # Handles the events coming from UI, forcing to refresh the encrypt
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
          text = send("help_for_#{m.id}")
          "<li>#{text}</li>"
        end

        texts.join
      end

      # Help text for the Regular Luks1 encryption method
      #
      # @return [String]
      def help_for_luks1
        encrypt_method = Y2Storage::EncryptionMethod.find(:luks1)

        format(
          # TRANSLATORS: help text for Regular Luks1 encryption method
          _("<p><b>%{label}</b>: allows to encrypt the device using LUKS1 " \
            "(Linux Unified Key Setup). You have to provide the encryption password.</p>"),
          label: encrypt_method.to_human_string
        )
      end

      # Help text for the Pervasive encryption method
      #
      # @return [String]
      def help_for_pervasive_luks2
        encrypt_method = Y2Storage::EncryptionMethod.find(:pervasive_luks2)

        format(
          # TRANSLATORS: Pervasive encryption terminology. For the English version see
          # https://www.ibm.com/support/knowledgecenter/linuxonibm/liaaf/lnz_r_crypt.html
          _("<p><b>%{label}</b>: allows to encrypt the device using LUKS2 with a master secure key " \
            "processed by a Crypto Express cryptographic coprocessor configured in CCA mode.</p>" \
            "<p>If the cryptographic system already contains a secure key associated to this " \
            "volume, that key will be used. Otherwise, a new secure key will be generated and " \
            "registered in the system. You need to provide an encryption password that will be " \
            "used to protect the access to that master key. Moreover, when there are several APQNs " \
            "in the system, you can select which ones to use.</p>"),
          label: encrypt_method.to_human_string
        )
      end

      # Help text for the Regular Luks2 encryption method
      #
      # @return [String]
      def help_for_luks2
        encrypt_method = Y2Storage::EncryptionMethod.find(:luks2)

        format(
          # TRANSLATORS: help text for Regular Luks2 encryption method
          _("<p><b>%{label}</b>: allows to encrypt the device using LUKS2. A variant of LUKS " \
            "(Linux Unified Key Setup) that uses a newer version of the header format. That " \
            "allows further possibilities like setting a label to reference the LUKS device " \
            "(for example, in the crypttab file). You have to provide the encryption password " \
            "and the password-based key derivation function (PBKDF) that will be used to protect " \
            "that passphrase.</p>" \
            "<p>The function to use depends on the context, the hardware capabilities and the " \
            "needed level of compatibility with other system components (see below).<p>" \
            "<p><b>PBKDF2</b> refers to the function of that name, according to RFC2898. Is the " \
            "function that LUKS1 uses.</p>" \
            "<p><b>Argon2id</b> and <b>Argon2i</b> refer to two variants of a function designed " \
            "to be more secure and to require a lot of memory to be computed.</p>" \
            "<p>Argon2 is more secure so it should be used if possible. But the large amount of " \
            "memory it uses (which is an intentional security feature) may result in problems " \
            "in some systems. If the strength of the password can be fully assured, then using " \
            "PBKDF2 may still be secure and save memory. On the other hand, Grub2 offers limited " \
            "support to boot from devices encrypted with LUKS2, but only if PBKDF2 is used. So " \
            "you cannot use Argon2 in a file system that contains the /boot directory. Note that " \
            "some manual Grub2 configuration may be needed to boot from a LUKS2 device, even if " \
            "PBKDF2 is used.</p>"),
          label: encrypt_method.to_human_string
        )
      end

      # Help text for the Random Swap encryption method
      #
      # @return [String]
      def help_for_random_swap
        encrypt_method = Y2Storage::EncryptionMethod.find(:random_swap)

        format(
          # TRANSLATORS: help text for Random Swap encryption method.
          _("<p><b>%{label}</b>: this encryption method uses randomly generated keys at boot and it " \
            "will not support Hibernation to hard disk. The swap device is re-encrypted during every " \
            "boot, and its previous content is destroyed. You should disable Hibernation through your " \
            "respective DE Power Management Utility and set it to Shutdown on Critical to avoid Data " \
            "Loss!</p>" \
            "<p>Note both the file system label and the UUID change every time the swap is " \
            "re-encrypted, so they are not valid options to mount a randomly encrypted swap " \
            "device.</p>" \
            "<p>It's also important to make sure the swap device is referenced in the /etc/crypttab " \
            "file by a stable name that is not subject to change on every reboot. For example, for " \
            "a swap partition it is safer to use the udev device id or path instead of the partition " \
            "device name, since that device name may be assigned to a different partition during the " \
            "next boot. If that happens, a wrong device could be encrypted instead of your swap!</p>" \
            "<p>YaST tries to use stable names in /etc/crypttab, unless it is configured to always " \
            "use device names (see the Settings section of the Partitioner). But for some devices " \
            "finding a fully stable name may not be possible. Please, only use encryption with " \
            "volatile keys if you are sure about the implications.</p>"),
          label: encrypt_method.to_human_string
        )
      end

      # Help text for the Protected Swap encryption method
      #
      # @return [String]
      def help_for_protected_swap
        random_swap = Y2Storage::EncryptionMethod.find(:random_swap)

        protected_swap = Y2Storage::EncryptionMethod.find(:protected_swap)

        format(
          # TRANSLATORS: help text for encryption method with protected keys for z Systems. See
          # https://www.ibm.com/support/knowledgecenter/en/linuxonibm/com.ibm.linux.z.lxdc/
          # lxdc_swapdisks_scenario.html
          _("<p><b>%{label}</b>: this encryption method uses a volatile protected AES key (without " \
            "requiring a cryptographic co-processor) to encrypt a swap device. This is an improvement " \
            "over %{random_swap_label} method and all considerations for such method still apply.</p>"),
          label:             protected_swap.to_human_string,
          random_swap_label: random_swap.to_human_string
        )
      end

      # Help text for the Secure Swap encryption method
      #
      # @return [String]
      def help_for_secure_swap
        random_swap = Y2Storage::EncryptionMethod.find(:random_swap)

        secure_swap = Y2Storage::EncryptionMethod.find(:secure_swap)

        format(
          # TRANSLATORS: help for encryption method with secure keys for z Systems. See
          # https://www.ibm.com/support/knowledgecenter/en/linuxonibm/com.ibm.linux.z.lxdc/
          # lxdc_swapdisks_scenario.html
          _("<p><b>%{label}</b>: this encryption method uses a volatile secure AES key (generated " \
            "from a cryptographic co-processor) for encrypting a swap device. This is an improvement " \
            "over %{random_swap_label} method and all considerations for such method still apply.</p>"),
          label:             secure_swap.to_human_string,
          random_swap_label: random_swap.to_human_string
        )
      end
    end
  end
end
