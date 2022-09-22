# Copyright (c) [2018-2021] SUSE LLC
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
require "yast2/popup"
require "y2storage/callbacks/issues_callback"
require "y2storage/storage_features_list"
require "y2storage/package_handler"

Yast.import "Mode"
Yast.import "Label"

module Y2Storage
  module Callbacks
    # Class to implement callbacks used during libstorage-ng probe
    class Probe < Storage::ProbeCallbacksV3
      include IssuesCallback

      include Yast::I18n

      include Yast::Logger

      # @param user_callbacks [UserProbe] Probing user callbacks
      def initialize(user_callbacks: nil)
        textdomain "storage"

        super()
        @user_callbacks = user_callbacks || UserProbe.new
      end

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
      def missing_command(message, what, command, used_features)
        # force the UTF-8 encoding to avoid Encoding::CompatibilityError exception
        message.force_encoding("UTF-8")
        what.force_encoding("UTF-8")
        command.force_encoding("UTF-8")

        log.info "libstorage-ng reported a missing command, asking the user whether to continue"
        log.info "Error details. message: #{message}. what: #{what}. command: #{command}. "\
                 "used_features: #{used_features}."

        packages = StorageFeaturesList.from_bitfield(used_features).pkg_list

        # Redirect to error callback if no packages can be installed.
        return error(message, what) unless can_install?(packages)

        answer = show_popup(packages)
        log.info "User answer: #{answer} (packages #{packages})"

        return true if answer == :ignore

        PackageHandler.new(packages).commit
        @again = true
        false
      end

      # Initialization
      def begin
        @again = false
      end

      # Should probing be run again?
      #
      # @return [Boolean] Whether probing should be run again
      def again?
        @again
      end

      private

      # @return [UserProbe] Probing user callbacks
      attr_reader :user_callbacks

      # Interactive pop-up, AutoYaST is not taken into account because this is
      # only used in normal mode, not in (auto)installation.
      def show_popup(packages)
        text = n_(
          "The following package needs to be installed to fully analyze the system:\n" \
          "%s\n\n" \
          "If you ignore this and continue without installing it, the system\n" \
          "information presented by YaST will be incomplete.",
          "The following packages need to be installed to fully analyze the system:\n" \
          "%s\n\n" \
          "If you ignore this and continue without installing them, the system\n" \
          "information presented by YaST will be incomplete.",
          packages.size
        ) % packages.sort.join(", ")

        buttons = { ignore: Yast::Label.IgnoreButton, install: Yast::Label.InstallButton }

        Yast2::Popup.show(text, buttons: buttons, focus: :install)
      end

      def can_install?(packages)
        if packages.empty?
          log.info "No packages to install"
          return false
        end

        if !Yast::Mode.normal
          log.info "Packages can only be installed in normal mode"
          return false
        end

        true
      end
    end
  end
end
