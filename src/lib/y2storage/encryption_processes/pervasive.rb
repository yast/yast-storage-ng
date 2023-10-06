# Copyright (c) [2019-2023] SUSE LLC
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

Yast.import "Mode"

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

      attr_reader :apqns

      # Creates an encryption layer over the given block device
      #
      # @param blk_device [Y2Storage::BlkDevice]
      # @param dm_name [String]
      # @param apqns [Array<Apqn>] APQNs to use for generating the secure key
      #
      # @return [Encryption]
      def create_device(blk_device, dm_name, apqns: [])
        @secure_key = SecureKey.for_device(blk_device)
        @apqns = apqns

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
      # generated.
      #
      # @param device [Encryption] encryption that will be created in the system
      def pre_commit(device)
        # For the time being, we will always generate a new key for each device
        # if there was not a preexisting one. In the future we can extend the
        # API to allow sharing a new key among several volumes.
        @secure_key ||= generate_secure_key(device)

        master_key_file = @secure_key.filename
        sector_size = sector_size_for(device.blk_device)

        # NOTE: The options cipher and key-size could also be influenced by setting
        # Encryption#cipher and Encryption#key_size. If those attributes have any value, the
        # correspoding format options are prepended to Encryption#format_options by libstorage-ng.
        device.format_options = "--master-key-file #{master_key_file.shellescape} --key-size 1024 "\
                                "--cipher paes-xts-plain64"
        device.format_options += " --sector-size #{sector_size}" if sector_size
        device.format_options += " --pbkdf pbkdf2"
      end

      # @see Base#post_commit
      #
      # Adds the device to the secure key if needed and executes the
      # extra commands reported by a call to "zkey cryptsetup".
      #
      # @param device [Encryption] encryption that has just been created in the system
      def post_commit(device)
        @secure_key.add_device_and_write(device) unless @secure_key.for_device?(device)

        zkey_cryptsetup_output = execute_zkey_cryptsetup(device)
        commands = zkey_cryptsetup_output[1..-1]
        return if commands.nil?

        commands.each do |command|
          args = command.split

          if args.any? { |arg| "setvp".casecmp(arg) == 0 }
            args += ["--key-file", "-"]
            Yast::Execute.locally(*args, stdin: device.password, recorder: cheetah_recorder)
          else
            Yast::Execute.locally(*args)
          end
        end
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

      # @see Base#encryption_type
      def encryption_type
        EncryptionType::LUKS2
      end

      private

      # @return [SecureKey] master key used to encrypt the device
      attr_reader :secure_key

      # @return [Array<String>] lines of the output of the "zkey cryptsetup"
      #   command executed during the pre-commit phase
      attr_reader :zkey_cryptsetup_output

      # Custom Cheetah recorder to prevent leaking the password to the logs
      #
      # @return [Recorder]
      def cheetah_recorder
        Recorder.new(Yast::Y2Logger.instance)
      end

      # Generates a new secure key for the given encryption device and
      # registers it into the keys database of the system. The secure
      # does not include the volume since that may not exist yet.
      #
      # @param device [Encryption]
      # @return [SecureKey]
      def generate_secure_key(device)
        key_name = "YaST_#{device.dm_table_name}"
        key = SecureKey.generate(
          key_name,
          sector_size: sector_size_for(device.blk_device),
          apqns:       apqns
        )
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
    end
  end
end
