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
require "y2storage/encryption_processes/secure_key"
require "yast2/execute"
require "yast"

module Y2Storage
  module EncryptionProcesses
    # Encryption process that allows to create and identify a volume encrypted
    # with Pervasive Encryption.
    #
    # For more information, see
    # https://www.ibm.com/support/knowledgecenter/linuxonibm/liaaf/lnz_r_dccnt.html
    class Pervasive < Base
      # Location of the zkey command
      ZKEY = "/usr/bin/zkey".freeze
      private_constant :ZKEY

      # @see Base#create_device
      def create_device(blk_device, dm_name)
        @secure_key = SecureKey.for_device(blk_device)
        if @secure_key
          # Should we discard the key if it's not a LUKS2 one?
          # Or maybe we should modify the secure key in that case?
          name_from_key = @secure_key.dm_name(blk_device)
          dm_name = name_from_key if name_from_key
        end

        super(blk_device, dm_name)
      end

      # @see Base#pre_commit
      #
      # If there is no secure key to be used for this device, a new key is
      # generated. In addition to that, the "zkey cryptsetup" command is
      # executed to know the sequence of commands that must be used to set the
      # pervasive encryption and the LUKS format options are adjusted
      # accordingly.
      #
      # @param device [Encryption] encryption that will be created in the system
      def pre_commit(device)
        # For the time being, we will always generate a new key for each device
        # if there was not a preexisting one. In the future we can extend the
        # API to allow sharing a new key among several volumes.
        @secure_key ||= generate_secure_key(device)

        @zkey_cryptsetup_output = execute_zkey_cryptsetup(device)
        return if @zkey_cryptsetup_output.empty?

        device.format_options = luksformat_options_string + " --pbkdf pbkdf2"
      end

      # @see Base#post_commit
      #
      # Executes the extra commands reported by the former call to
      # "zkey cryptsetup".
      #
      # @param device [Encryption] encryption that has just been created in the system
      def post_commit(device)
        commands = zkey_cryptsetup_output[1..-1]
        return if commands.nil?

        commands.each do |command|
          args = command.split(" ")

          if args.any? { |arg| "setvp".casecmp(arg) == 0 }
            args += ["--key-file", "-"]
            Yast::Execute.locally(*args, stdin: device.password, recorder: cheetah_recorder)
          else
            Yast::Execute.locally(*args)
          end
        end
      end

      # Encryption options to add to the encryption device (crypttab options)
      #
      # @param blk_device [BlkDevice] Block device to encrypt
      # @return [Array<String>]
      def crypt_options(blk_device)
        [sector_size_option(blk_device)].compact
      end

      # @see Base#finish_installation
      #
      # Copies the keys from the zkey repository of the inst-sys to the
      # repository of the target system.
      def finish_installation
        secure_key.copy_to_repository(Yast::Installation.destdir)
      end

      # Class to prevent Yast::Execute from leaking to the logs the password
      # provided via stdin
      class Recorder < Cheetah::DefaultRecorder
        # To prevent leaking stdin, just do nothing
        def record_stdin(_stdin); end
      end

      private

      # @return [SecureKey] master key used to encrypt the device
      attr_reader :secure_key

      # @return [Array<String>] lines of the output of the "zkey cryptsetup"
      #   command executed during the pre-commit phase
      attr_reader :zkey_cryptsetup_output

      # @see Base#encryption_type
      def encryption_type
        EncryptionType::LUKS2
      end

      # Custom Cheetah recorder to prevent leaking the password to the logs
      #
      # @return [Recorder]
      def cheetah_recorder
        Recorder.new(Yast::Y2Logger.instance)
      end

      # Generates a new secure key for the given encryption device and registers
      # it into the keys database of the system
      #
      # @param device [Encryption]
      # @return [SecureKey]
      def generate_secure_key(device)
        key_name = "YaST_#{device.dm_table_name}"
        key = SecureKey.generate(key_name, volumes: [device], sector_size: sector_size_for(device.blk_device))
        log.info "Generated secure key #{key.name}"

        key
      end

      # Executes the "zkey cryptsetup" used to get the list of commands that
      # must be executed during the pervasive encryption process
      #
      # @return [Array<String>]
      def execute_zkey_cryptsetup(device)
        name = secure_key.plain_name(device)
        command = [ZKEY, "cryptsetup", "--volumes", name]
        Yast::Execute.locally(*command, stdout: :capture)&.lines&.map(&:strip) || []
      end

      # Options to be passed to the "cryptsetup luksFormat" during the commit
      # phase
      #
      # @see Luks#format_options
      #
      # @return [String]
      def luksformat_options_string
        luksformat_command = zkey_cryptsetup_output.first
        luksformat_command.split("luksFormat ").last.gsub(/ \/dev[^\s]*/, "")
      end
    end
  end
end
