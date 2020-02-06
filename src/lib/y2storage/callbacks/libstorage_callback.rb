# Copyright (c) [2018,2020] SUSE LLC
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
require "storage"
require "y2storage/storage_env"
require "ui/text_helpers"

Yast.import "Report"
Yast.import "Popup"
Yast.import "Label"
Yast.import "Mode"

module Y2Storage
  module Callbacks
    # Mixin with methods that are common to all kind of callbacks used for the
    # interaction with libstorage-ng.
    module LibstorageCallback
      include Yast::Logger
      include Yast::I18n
      include UI::TextHelpers

      # Callback for libstorage-ng to show a message to the user.
      #
      # Currently it performs no action, we don't want to bother the regular
      # user with information about every single step. Libstorage-ng is
      # already writing that information to the YaST logs.
      #
      # @param message [String] message text (in the ASCII-8BIT encoding!,
      #   see https://sourceforge.net/p/swig/feature-requests/89/,
      #   it is recommended to force it to the UTF-8 encoding before
      #   doing anything with the string to avoid the Encoding::CompatibilityError
      #   exception!)
      # See Storage::Callbacks#message in libstorage-ng
      def message(message); end

      # Callback for libstorage-ng to report an error to the user.
      #
      # In addition to displaying the error, it offers the user the possibility
      # to ignore it and continue.
      #
      # @note If the user rejects to continue, the method will return false
      # which implies libstorage-ng will raise the corresponding exception for
      # the error.
      #
      # See Storage::Callbacks#error in libstorage-ng
      #
      # @param message [String] error title coming from libstorage-ng
      #   (in the ASCII-8BIT encoding! see https://sourceforge.net/p/swig/feature-requests/89/)
      # @param what [String] details coming from libstorage-ng (in the ASCII-8BIT encoding!)
      # @return [Boolean] true will make libstorage-ng ignore the error, false
      #   will result in a libstorage-ng exception
      def error(message, what)
        textdomain "storage"

        # force the UTF-8 encoding to avoid Encoding::CompatibilityError exception (bsc#1096758)
        message.force_encoding("UTF-8")
        what.force_encoding("UTF-8")

        log.info "libstorage-ng reported an error, asking the user whether to continue"
        log.info "Error details. Message: #{message}. What: #{what}."

        description = error_description(what)
        question = _("Continue despite the error?")

        buttons = { yes: Yast::Label.ContinueButton, no: abort_button_label }
        focus = default_answer_to_error ? :yes : :no

        result = Yast::Report.yesno_popup(
          full_message(message, description, question, what), details: wrap_text(what),
          focus: focus, buttons: buttons
        )

        log.info "User answer: #{result}"
        result
      end

      # Label for the abort button displayed by {#error}
      #
      # @return [String]
      def abort_button_label
        Yast::Mode.installation ? Yast::Label.AbortInstallationButton : Yast::Label.AbortButton
      end

      # Default result for {#error}
      #
      # This is specially relevant in AutoYaST, since it will be the chosen
      # answer if the timeout for the question is reached.
      #
      # @return [Boolean]
      def default_answer_to_error
        true
      end

      # Human-readable description of the problem reported by libstorage-ng,
      # hopefully with some hint on how to resolve it or continue.
      #
      # A generic message is returned if no concrete problem can be identified.
      #
      # @see #error
      #
      # @param what [String] details coming from libstorage-ng
      # @return [String]
      def error_description(what)
        if what.match?(/WARNING: PV .* was already found on .*/i)
          duplicated_pv_description
        else
          _("Unexpected situation found in the system.")
        end
      end

      # Human-readable description to use if the LVM tools report that the same
      # PV is found more than once.
      #
      # @see #error_description
      #
      # @return [String]
      def duplicated_pv_description
        result = _("The same LVM physical volume was found in several devices.\n")
        # The user already tried LIBSTORAGE_MULTIPATH_AUTOSTART (and is not
        # using AutoYaST), there is nothing else we can advise.
        return result.chomp if forced_multipath? && !Yast::Mode.auto

        result += _(
          "Maybe there are multipath devices in the system but multipath support\n" \
          "was not enabled.\n\n"
        )

        result += if Yast::Mode.auto
          _(
            "Use 'start_multipath' in the AutoYaST profile to enable multipath."
          )
        else
          _(
            "If YaST didn't offer the opportunity to enable multipath in a previous step,\n" \
            "try the 'LIBSTORAGE_MULTIPATH_AUTOSTART=ON' boot parameter.\n" \
            "More information at https://en.opensuse.org/SDB:Linuxrc"
          )
        end
        result
      end

      # Whether the activation of multipath has been forced via the
      # LIBSTORAGE_MULTIPATH_AUTOSTART boot parameter
      #
      # @see StorageEnv#forced_multipath?
      #
      # @return [Boolean]
      def forced_multipath?
        StorageEnv.instance.forced_multipath?
      end

      private

      # Generate the full message for the error popup.
      #
      # @return [String] Full message.
      #
      def full_message(message, description, question, what)
        hint = _("Click below to see more details (English only).")

        if what.empty?
          "#{message}\n\n#{description}\n\n#{question}"
        else
          "#{message}\n\n#{description}\n\n#{hint}\n\n#{question}"
        end
      end
    end
  end
end
