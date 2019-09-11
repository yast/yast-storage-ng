# encoding: utf-8
#
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
    class Swap < Base
      URANDOM = "/dev/urandom".freeze
      SWAP = "swap".freeze

      private_constant :URANDOM
      private_constant :SWAP

      def self.used_for?(encryption)
        encryption.crypt_options.any? { |opt| opt.downcase == SWAP }
      end

      def create_device(blk_device, dm_name)
        enc = super
        enc.key_file = key_file
        enc.crypt_options = crypt_options + enc.crypt_options
        enc
      end

      private

      def encryption_type
        EncryptionType::PLAIN
      end

      def crypt_options
        [SWAP]
      end

      def key_file
        URANDOM
      end
    end
  end
end
