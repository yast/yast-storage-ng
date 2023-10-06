# Copyright (c) [2023] SUSE LLC
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

require "yast2/execute"
require "yast"
require "y2storage/encryption_type"
require "y2storage/encryption_processes/fde_tools"
require "y2storage/encryption_processes/fde_tools_config"

Yast.import "Mode"

module Y2Storage
  module EncryptionProcesses
    # Encryption process that allow to setup device unlocking via the TPM2 chip
    # based on the fde-tools shipped with (open)SUSE distributions
    #
    # The process is only valid for the system installation case, adding devices in an
    # already installed system may imply different steps.
    #
    # This assumes all the devices use the same recovery password. That's a fde-tools
    # requirement.
    class TpmFdeTools < Base
      # Options to add to the fourth column of crypttab for all involved devices
      CRYPT_OPTIONS = ["x-initrd.attach"]
      private_constant :CRYPT_OPTIONS

      # Content of the third column of crypttab for all involved devices
      KEY_FILE_NAME = "/.fde-virtual.key".freeze
      private_constant :KEY_FILE_NAME

      # Content of the third column of crypttab for all involved devices
      #
      # @return [String]
      def self.key_file_name
        KEY_FILE_NAME.dup
      end

      # Class methods
      class << self
        # List of all block devices configured by fde-tools during system installation
        attr_accessor :devices
      end

      # Creates an encryption layer over the given block device
      #
      # @param blk_device [Y2Storage::BlkDevice]
      # @param dm_name [String]
      # @param label [String] optional LUKS2 label
      #
      # @return [Encryption]
      def create_device(blk_device, dm_name, label: nil)
        enc = super(blk_device, dm_name)
        enc.label = label if label
        enc.crypt_options |= CRYPT_OPTIONS
        enc.key_file = self.class.key_file_name
        enc.use_key_file_in_commit = false
        # Maybe this configuration value affects only the slots added by fde-tools. In that
        # case we could use any other PBKDF here. But being consistent with the PBKDF used
        # in the fde-tools slots looks like a safer bet in this first implementation.
        enc.pbkdf = FdeToolsConfig.instance.pbkd_function
        enc
      end

      # @see Base#encryption_type
      def encryption_type
        EncryptionType::LUKS2
      end

      # @see Base#post_commit
      #
      # TODO: this implemented only for the installation case. In an installed system the procedure
      # would be completely different and will likely include steps like configuring the fde-tools,
      # calling "fdectl regenerate-key" and regenerating initrd and the bootloader configuration.
      #
      # @param device [Encryption] encryption that has just been created in the system
      def post_commit(device)
        return unless Yast::Mode.installation

        self.class.devices ||= []
        self.class.devices << device
      end

      # @see Base#finish_installation
      def finish_installation
        # This process is only needed once
        return if self.class.devices.empty?

        return unless configure_fde_tools(self.class.devices)

        fde = FdeTools.new(recovery_password)
        fde.add_secondary_password && fde.add_secondary_key && fde.enroll_service&.enable

        # Mark as done
        self.class.devices = []
      end

      # @see Base#commit_features
      def commit_features
        # In installation mode is needed to ensure the enroll service is present in the new system.
        # In an installed system is needed in order to be able to execute the fdectl commands.
        [YastFeature::ENCRYPTION_TPM_FDE]
      end

      private

      # Configure fde-tools to act on all the involved block devices
      #
      # @return [Boolean] true if fde-tools were correctly configured
      def configure_fde_tools(devices)
        plain_devices = plain_names(devices)
        config = FdeToolsConfig.instance
        config.devices = plain_devices

        # Check if everything went well
        config.devices == plain_devices
      end

      # Device names of all the block devices being configured
      #
      # @return [Array<String>]
      def plain_names(devices)
        devices.map { |d| d.plain_device.preferred_name }.sort
      end

      # Shared password used in the interactive slot of all affected devices
      #
      # @return [String]
      def recovery_password
        self.class.devices.first.password
      end
    end
  end
end
