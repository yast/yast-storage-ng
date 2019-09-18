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
require "y2storage/encryption_processes/secure_key"
require "yast2/execute"

module Y2Storage
  module EncryptionProcesses
    class Pervasive < Base
      def self.used_for?(encryption)
        # TODO: it should be possible to detect a preexisting pervasive encryption
        # after extending a bit the libstorage-ng probing capabilities.
        super
      end

      def self.available?
        SecureKey.available?
      end

      def create_device(blk_device, dm_name)
        @secure_key = SecureKey.for_plain_device(blk_device)
        if @secure_key
          name_from_key = @secure_key.dm_name(blk_device)
          dm_name = name_from_key if name_from_key
        end

        super(blk_device, dm_name)
      end

      def pre_commit(device)
        # For the time being, we will always generate a new key for each device
        # if there was not a preexisting one. In the future we can extend the
        # API to allow sharing a new key among several volumes
        @secure_key ||= generate_secure_key(device)

        @zkey_cryptsetup_output = execute_zkey_cryptsetup(device)
        device.format_options = luksformat_options_string + " --pbkdf pbkdf2"
      end

      def post_commit(device)
        zkey_cryptsetup_output[1..-1].each do |command|
          args = command.split(" ")

          if args.any? { |arg| "setvp".casecmp(arg) == 0 }
            args += ["--key-file", "-"]
            Yast::Execute.locally(*args, stdin: device.password, recorder: cheetah_recorder)
          else
            Yast::Execute.locally(*args)
          end
        end
      end

      # Custom Cheetah recorder to prevent leaking the password to the logs
      def cheetah_recorder
        @cheetah_recorder ||= Recorder.new(Yast::Y2Logger.instance)
      end

      # Class to prevent Yast::Execute from leaking to the logs the password
      # provided via stdin
      class Recorder < Cheetah::DefaultRecorder
        # To prevent leaking stdin, just do nothing
        def record_stdin(_stdin); end
      end

      private

      attr_reader :secure_key
      attr_reader :zkey_cryptsetup_output

      def encryption_type
        EncryptionType::LUKS2
      end

      def generate_secure_key(device)
        key_name = "YaST_#{device.dm_table_name}"
        key = SecureKey.generate(key_name, volumes: [device])
        log.info "Generated secure key #{key.name}"

        key
      end

      # @return [String]
      def execute_zkey_cryptsetup(device)
        # TODO: proper name attribute
        command = ["zkey", "cryptsetup", "--volumes", device.blk_device.name]
        Yast::Execute.locally(*command, stdout: :capture).lines.map(&:strip)
      end

      def luksformat_options_string
        luksformat_command.split("luksFormat ").last.gsub(/ \/dev[^\s]*/, "")
      end

      def luksformat_command
        zkey_cryptsetup_output.first
      end
    end
  end
end
