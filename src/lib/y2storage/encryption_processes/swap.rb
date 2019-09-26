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

require "y2storage/encryption_processes/base"
require "y2storage/encryption_type"

module Y2Storage
  module EncryptionProcesses
    # Base class for encryption processes that use an ephemeral password to encrypt a swap device
    #
    # Swap based methods use plain encryption technology to encrypt the swap device with a new password
    # generated at boot time. Generally, the new password is generated based on /dev/urandom data (see
    # {RandomSwap}), but IBM offers other mechanisms for z Systems (see {ProtectedSwap} and {SecureSwap}
    # processes).
    class Swap < Base
      SWAP_OPTION = "swap".freeze
      private_constant :SWAP_OPTION

      class << self
        # @see Base.available?
        def available?
          File.exist?(key_file)
        end

        # @see Base.only_for_swap?
        def only_for_swap?
          true
        end

        # @see Base.used_for?
        def used_for?(encryption)
          used?(encryption.key_file, encryption.crypt_options)
        end

        # @see Base.used_for_crypttab?
        def used_for_crypttab?(entry)
          used?(entry.password, entry.crypt_options)
        end

        # Encryption key file
        #
        # Each Swap process could use a different key file.
        #
        # @raise [RuntimeError] if no key file has been defined.
        #
        # @return [String]
        def key_file
          raise "No key file indicated!"
        end

        # Encryption cipher
        #
        # Each Swap process could use a different cipher.
        #
        # @return [String, nil] nil if no specific cipher
        def cipher
          nil
        end

        # Size of the encryption key
        #
        # @return [String, nil] nil if no specific size
        def key_size
          nil
        end

        # Sector size for the encryption
        #
        # @return [String, nil] nil if no specific sector size
        def sector_size
          nil
        end

        # Encryption options to add to the encryption device (crypttab options)
        #
        # @return [Array<String>]
        def crypt_options
          [swap_option, cipher_option, key_size_option, sector_size_option].compact
        end

        # Encryption options to open the encryption device
        #
        # @return [Array<String>]
        def open_options
          [cipher_open_option, key_size_open_option, sector_size_open_option].compact
        end

        # Wheter a specific cipher is used
        #
        # @return [Boolean]
        def cipher?
          !cipher.nil?
        end

        # Whether a specific key size is used
        #
        # @return [Boolean]
        def key_size?
          !key_size.nil?
        end

        # Whether a specific sector size is used
        def sector_size?
          !sector_size.nil?
        end

        private

        # Swap option for the crypttab file
        #
        # @return [String]
        def swap_option
          SWAP_OPTION
        end

        # Cipher option for the crypttab file
        #
        # @return [String, nil] nil if no specific cipher
        def cipher_option
          return nil unless cipher?

          "cipher=#{cipher}"
        end

        # Key size option for the crypttab file
        #
        # @return [String, nil] nil if no specific size
        def key_size_option
          return nil unless key_size?

          "size=#{key_size}"
        end

        # Sector size option for the encryption
        #
        # @return [String, nil] nil if no specific sector size
        def sector_size_option
          return nil unless sector_size?

          "sector-size=#{sector_size}"
        end

        # Cipher option to open the encryption device
        #
        # @return [String, nil] nil if no specific cipher
        def cipher_open_option
          return nil unless cipher?

          "--cipher '#{cipher}'"
        end

        # Key size option to open the encryption device
        #
        # @return [String, nil] nil if no specific size
        def key_size_open_option
          return nil unless key_size?

          "--key-size '#{key_size}'"
        end

        # Sector size option to open the encryption device
        #
        # @return [String, nil] nil if no specific sector size
        def sector_size_open_option
          return nil unless sector_size?

          "--sector-size '#{sector_size}'"
        end

        # Checks whether the process was used according to the given key file and encrytion options
        #
        # @param key_file [String]
        # @param crypt_options [Array<String>]
        def used?(key_file, crypt_options)
          contain_swap_option?(crypt_options) && use_key_file?(key_file)
        end

        # Whether the given encryption device contains the swap option
        #
        # @param crypt_options [Array<String>]
        # @return [Boolean]
        def contain_swap_option?(crypt_options)
          crypt_options.any? { |o| o.casecmp?(swap_option) }
        end

        # Whether the given encryption device is using the key file for this process
        #
        # @param key_file [String]
        # @return [Boolean]
        def use_key_file?(key_file)
          key_file == self.key_file
        end
      end

      # @see Base#create_device
      def create_device(blk_device, dm_name)
        enc = super
        enc.key_file = key_file
        enc.crypt_options = crypt_options + enc.crypt_options
        enc
      end

      # @see Base#encryption_type
      def encryption_type
        EncryptionType::PLAIN
      end

      # @see Swap.key_file
      def key_file
        self.class.key_file
      end

      # @see Swap.crypt_options
      def crypt_options
        self.class.crypt_options
      end

      # @see Swap.open_options
      def open_options
        self.class.open_options
      end
    end
  end
end
