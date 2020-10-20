# encoding: utf-8

# Copyright (c) 2018 SUSE LLC
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

module Y2Storage
  module Callbacks
    # Class to implement callbacks used during libstorage-ng probe
    class Probe < Storage::ProbeCallbacks
      include LibstorageCallback

      # Callback for libstorage-ng to report an error to the user.
      #
      # If the $LIBSTORAGE_IGNORE_PROBE_ERRORS environment variable is set,
      # this just returns 'true', i.e. the error is ignored.
      #
      # Otherwise, this displays the error and prompts the user if the error
      # should be ignored.
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
        return true if StorageEnv.instance.ignore_probe_errors?

        super(message, what)
      end
    end
  end
end
