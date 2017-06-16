#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015-2017] SUSE LLC
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

require "yast"
require "y2storage/secret_attributes"

module Y2Storage
  module Planned
    # Mixing for planned devices that can have an encryption layer on top.
    # @see Planned::Device
    module CanBeEncrypted
      include SecretAttributes

      # This value matches Storage::Luks.metadata_size, which is not exposed in
      # the libstorage API
      ENCRYPTION_OVERHEAD = DiskSize.MiB(2)
      private_constant :ENCRYPTION_OVERHEAD

      # @!attribute encryption_password
      #   @return [String, nil] password used to encrypt the device. If is nil,
      #     it means the device will not be encrypted
      secret_attr :encryption_password

      # Initializations of the mixin, to be called from the class constructor.
      def initialize_can_be_encrypted
      end

      # Checks whether the resulting device must be encrypted
      #
      # @return [Boolean]
      def encrypt?
        !encryption_password.nil?
      end

      # Returns the (possibly encrypted) device to be used for the planned
      # device.
      #
      # If encryption is requested by the planned device, the method will
      # encrypt the plain device and will return the corresponding encrypted
      # one. Otherwise, it will simply return the plain device.
      #
      # FIXME: temporary API. It should be improved.
      #
      # @param plain_device [BlkDevice]
      # @return [BlkDevice]
      def final_device!(plain_device)
        result = super
        if create_encryption?
          result = result.create_encryption(dm_name_for(result))
          result.password = encryption_password
          log.info "Device encrypted. Returning the new device #{result.inspect}"
        else
          log.info "No need to encrypt. Returning the existing device #{result.inspect}"
        end
        result
      end

      def self.included(base)
        base.extend(ClassMethods)
      end

    protected

      def create_encryption?
        return false unless encrypt?
        return true unless reuse?
        return reformat? if respond_to?(:reformat?)
        false
      end

      # DeviceMapper name to use for the encrypted version of the given device.
      #
      # FIXME: with the current implementation (using the device kernel name
      # instead of UUID or something similar), the DeviceMapper for an encrypted
      # /dev/sda5 would be "cr_sda5", which implies a quite high risk of
      # collision with existing DeviceMapper names.
      #
      # Revisit this after improving libstorage-ng capabilities about
      # alternative names and DeviceMapper.
      #
      # FIXME: this should probably be moved to Encryption.
      #
      # @return [String]
      def dm_name_for(device)
        "cr_#{device.basename}"
      end

      # Class methods for the mixin
      module ClassMethods
        # Space that will be used by the encryption data structures in a device.
        # I.e. how much smaller will be an encrypted device compared to the plain
        # one.
        #
        # @return [DiskSize]
        def encryption_overhead
          ENCRYPTION_OVERHEAD
        end
      end
    end
  end
end
