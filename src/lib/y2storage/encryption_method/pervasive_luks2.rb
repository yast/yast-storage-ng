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
# Copyright (c) [2019] SUSE LLC

require "y2storage/encryption_method/base"
require "y2storage/encryption_processes/pervasive"
require "y2storage/encryption_processes/secure_key"

module Y2Storage
  module EncryptionMethod
    class PervasiveLuks2 < Base
      # Cipher used for pervasive encryption
      CIPHER = "paes-xts-plain64".freeze
      private_constant :CIPHER

      def initialize
        super(:pervasive_luks2, _("Pervasive Volume Encryption"), EncryptionProcesses::Pervasive)
      end

      # @see Base#used_for?
      def used_for?(encryption)
        encryption.type.is?(:luks2) && encryption.cipher == CIPHER
      end

      # @see Base#available?
      def available?
        EncryptionProcesses::SecureKey.available?
      end

      private

      # @see Base#encryption_process
      def encryption_process
        EncryptionProcesses::Pervasive.new(self)
      end
    end
  end
end
