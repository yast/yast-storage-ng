# encoding: utf-8

# Copyright (c) [2017-2018] SUSE LLC
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
require "y2storage/dialogs/callbacks/activate_luks"
require "y2storage/callbacks/libstorage_callback"

Yast.import "Popup"

module Y2Storage
  module Callbacks
    # Class to implement callbacks used during libstorage-ng activation
    class Activate < Storage::ActivateCallbacks
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

        Yast::Popup.YesNo(
          _(
            "The system seems to have multipath hardware.\n"\
            "Do you want to activate multipath?"
          )
        )
      end

      def luks(uuid, attempt)
        log.info("Trying to open luks UUID: #{uuid} (#{attempt} attempts)")
        dialog = Dialogs::Callbacks::ActivateLuks.new(uuid, attempt)
        result = dialog.run

        activate = result == :accept
        password = activate ? dialog.encryption_password : ""

        Storage::PairBoolString.new(activate, password)
      end

      # Whether the activation of multipath has been forced via the
      # LIBSTORAGE_MULTIPATH_AUTOSTART boot parameter
      #
      # See https://en.opensuse.org/SDB:Linuxrc for details and see
      # bsc#1082542 for an example of scenario in which this is needed.
      #
      # @return [Boolean]
      def forced_multipath?
        # Sort the keys to have a deterministic behavior and to prefer
        # all-uppercase over the other variants, then do a case insensitive
        # search
        key = ENV.keys.sort.find { |k| k.match(/\ALIBSTORAGE_MULTIPATH_AUTOSTART\z/i) }
        return false unless key

        log.debug "Found key about forcing multipath: #{key.inspect}"
        value = ENV[key]
        # Similar to what linuxrc does, also consider the flag activated if the
        # variable is used with no value or with "1"
        value.casecmp?("on") || value.empty? || value == "1"
      end
    end
  end
end
