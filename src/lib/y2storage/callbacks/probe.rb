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

require "y2storage/callbacks/libstorage_callback"
require "y2storage/storage_features_list"
require "y2storage/package_handler"

Yast.import "Mode"
Yast.import "Label"
Yast.import "Popup"

module Y2Storage
  module Callbacks
    # Class to implement callbacks used during libstorage-ng probe
    class Probe < Storage::ProbeCallbacksV3
      include LibstorageCallback

      # Callback for missing commands during probing.
      #
      # @param message [String] error title coming from libstorage-ng
      #   (in the ASCII-8BIT encoding! see https://sourceforge.net/p/swig/feature-requests/89/)
      # @param what [String] details coming from libstorage-ng (in the ASCII-8BIT encoding!)
      # @param command [String] missing command coming from libstorage-ng (in the ASCII-8BIT encoding!)
      # @param used_features [Integer] used features bit field as integer coming from libstorage-ng
      #
      # @return [Boolean] true will make libstorage-ng ignore the error, false
      #   will result in a libstorage-ng exception
      #
      def missing_command(message, what, command, used_features)
        textdomain "storage"

        # force the UTF-8 encoding to avoid Encoding::CompatibilityError exception
        message.force_encoding("UTF-8")
        what.force_encoding("UTF-8")
        command.force_encoding("UTF-8")

        log.info "libstorage-ng reported a missing command, asking the user whether to continue"
        log.info "Error details. message: #{message}. what: #{what}. command: #{command}. "\
                 "used_features: #{used_features}."

        # Redirect to error callback if no packages can be installed.
        return error(message, what) if used_features == 0 || Yast::Mode.installation

        packages = StorageFeaturesList.new(used_features).pkg_list

        # Redirect to error callback if no packages can be installed.
        return error(message, what) if packages.empty?

        description = _("An external command required for probing is missing. When\n"\
                        "continuing despite the error, the presented system information\n"\
                        "will be incomplete. You may also install the required packages\n"\
                        "and restart probing.")

        what += "\n\n" + missing_command_handle_packages_text(packages)

        question = _("Continue despite the error, install required packages or abort?")
        buttons = { continue: Yast::Label.ContinueButton, install: _("Install Packages"),
                    abort: Yast::Label.AbortButton }

        result = Yast2::Popup.show(full_message(message, description, question, what),
          details: wrap_text(what), buttons: buttons, focus: :install)
        log.info "User answer: #{result}"

        missing_command_handle_user_decision(result, packages)
      end

      # Initialization.
      #
      def begin
        @again = false
      end

      # Should probing be run again?
      #
      # @return [Boolean] Whether probing should be run again.
      #
      def again?
        @again
      end

      private

      # Generates the text for the packages that must be installed.
      #
      # @param packages [Array<String>] names of the packages to be installed
      # @return [String] The text.
      #
      def missing_command_handle_packages_text(packages)
        n_("The following package needs to be installed:",
          "The following packages need to be installed:", packages.size) + "\n" +
          packages.sort.join(", ")
      end

      # Handles the result from the popup.
      #
      # @return [Boolean] Whether probing should continue.
      #
      def missing_command_handle_user_decision(result, packages)
        case result

        when :install
          PackageHandler.new(packages).commit
          @again = true
          false

        when :continue
          @again = false
          true

        when :abort
          @again = false
          false

        end
      end
    end
  end
end
