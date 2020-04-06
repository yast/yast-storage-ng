# Copyright (c) [2017-2020] SUSE LLC
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

require "y2storage/dialogs/callbacks/activate_luks"
require "y2storage/callbacks/libstorage_callback"
require "y2storage/storage_env"

module Y2Storage
  module Callbacks
    # Class to implement callbacks used during libstorage-ng activation
    #
    # Note that this class provides an implementation for the specialized callbacks
    # `Storage::ActivateCallbacksLuks` instead of `Storage::ActivateCallbacks`. That specialized
    # callbacks receives a more generic parameter when activating LUKS devices.
    class Activate < Storage::ActivateCallbacksLuks
      include LibstorageCallback
      include Yast::Logger
      include Yast::I18n

      def initialize
        textdomain "storage"
        super
      end

      # Decides whether multipath should be activated
      #
      # The argument indicates whether libstorage-ng detected a multipath setup
      # in the system. Beware such detection is not reliable (see bsc#1082542).
      #
      # @param looks_like_real_multipath [Boolean] true if the system seems to
      #   contain a Multipath
      # @return [Boolean]
      def multipath(looks_like_real_multipath)
        return true if forced_multipath?
        return false unless looks_like_real_multipath

        message = _(
          "The system seems to have multipath hardware.\n" \
          "Do you want to activate multipath?"
        )

        Yast2::Popup.show(message, buttons: :yes_no) == :yes
      end

      # Decides whether a LUKS device should be activated
      #
      # @param info [Storage::LuksInfo]
      # @param attempt [Numeric]
      #
      # @return [Storage::PairBoolString]
      def luks(info, attempt)
        log.info("Trying to open luks UUID: #{info.uuid} (#{attempt} attempts)")

        return Storage::PairBoolString.new(false, "") if !StorageEnv.instance.activate_luks?

        luks_error(attempt) if attempt > 1

        dialog = Dialogs::Callbacks::ActivateLuks.new(info, attempt)
        result = dialog.run

        activate = result == :accept
        password = activate ? dialog.encryption_password : ""

        Storage::PairBoolString.new(activate, password)
      end

      private

      # Error popup when the LUKS could not be activated
      #
      # @param attempt [Numeric] current attempt
      def luks_error(attempt)
        message = format(
          _("The encrypted volume could not be activated (attempt number %{attempt}).\n\n" \
            "Please, make sure you are entering the correct password."),
          attempt: attempt - 1
        )

        Yast2::Popup.show(message, headline: :error, buttons: :ok)

        nil
      end
    end
  end
end
