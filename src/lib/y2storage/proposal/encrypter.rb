#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

require "storage"

module Y2Storage
  module Proposal
    # Utility class to encrypt devices and provide information related to
    # encryption
    class Encrypter
      include Yast::Logger

      # This value matches Storage::Luks.metadata_size, which is not exposed in
      # the libstorage API
      DEVICE_OVERHEAD = DiskSize.MiB(2)
      private_constant :DEVICE_OVERHEAD

      # Returns the (possibly encrypted) device to be used for the planned
      # device.
      #
      # If encryption is requested by the planned device, the method will
      # encrypt the plain device and will return the corresponding encrypted
      # one. Otherwise, it will simply return the plain device.
      #
      # @param planned [Planned::Device]
      # @param plain_device [BlkDevice]
      # @return [BlkDevice]
      def device_for(planned, plain_device)
        log.info "Checking if the device must be encrypted #{planned.inspect}"

        if !planned.respond_to?(:encrypt?) || !planned.encrypt?
          log.info "No encryption. Returning the plain device. #{plain_device.inspect}"
          return plain_device
        end

        result = plain_device.create_encryption(dm_name_for(plain_device))
        result.password = planned.encryption_password
        log.info "Device encrypted. Returning the new device #{result.inspect}"
        result
      end

      # Space that will be used by the encryption data structures in a device.
      # I.e. how much smaller will be an encrypted device compared to the plain
      # one.
      #
      # @return [DiskSize]
      def device_overhead
        DEVICE_OVERHEAD
      end

    protected

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
      # @return [String]
      def dm_name_for(device)
        name = device.name.split("/").last
        "cr_#{name}"
      end
    end
  end
end
