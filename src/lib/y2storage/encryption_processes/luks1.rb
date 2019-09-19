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

require "y2storage/encryption_type"
require "y2storage/encryption_processes/base"

module Y2Storage
  module EncryptionProcesses
    # The encryption process that allows to create and identify an encrypted
    # device using LUKS1
    class Luks1 < Base
      # Whether the process was used for the given encryption device
      #
      # @param encryption [Y2Storage::Encryption] the encryption device to check
      # @return [Boolean] true when the encryption type is LUKS1; false otherwise
      def self.used_for?(encryption)
        encryption.type.is?(:luks1)
      end

      private

      # @see EncryptionProcesses::Base#encryption_type
      def encryption_type
        EncryptionType::LUKS1
      end
    end
  end
end
