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

require "y2storage/encryption_processes/swap"

module Y2Storage
  module EncryptionProcesses
    # Encryption swap process (see {Swap}) to encrypt a device by using random password
    class RandomSwap < Swap
      KEY_FILE = "/dev/urandom".freeze
      private_constant :KEY_FILE

      class << self
        # @see Swap.key_file
        def key_file
          KEY_FILE
        end
      end
    end
  end
end
