# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

require "y2storage/storage_class_wrapper"

module Y2Storage
  # Information about one entry in crypttab
  #
  # This is a wrapper for Storage::SimpleEtcCrypttabEntry
  class SimpleEtcCrypttabEntry
    include StorageClassWrapper
    wrap_class Storage::SimpleEtcCrypttabEntry

    # @!method name
    #   @return [String] name of the resulting encrypted block device
    storage_forward :name

    # @!method device
    #   @return [String] path to the underlying block device
    storage_forward :device

    # @!method password
    #   @return [String]
    storage_forward :password

    # @!method crypt_options
    #   @return [Array<String>]
    storage_forward :crypt_options

    # Device for the crypttab entry
    #
    # @param devicegraph [Devicegraph]
    # @return [BlkDevice, nil] nil if the device is not found
    def find_device(devicegraph)
      if device_by_uuid?
        find_device_by_uuid(devicegraph)
      elsif device_by_label?
        find_device_by_label(devicegraph)
      else
        find_device_by_name(devicegraph)
      end
    end

  private

    # Whether the crypttab device is indicated by UUID
    #
    # The second field in the crypttab entry contains something
    # like "UUID=1212345454-34343".
    #
    # @return [Boolean]
    def device_by_uuid?
      /^UUID=(.*)/.match?(device)
    end

    # Whether the crypttab device is indicated by LABEL
    #
    # The second field in the crypttab entry contains something
    # like "LABEL=device_label".
    #
    # @return [Boolean]
    def device_by_label?
      /^LABEL=(.*)/.match?(device)
    end

    # TODO: using old storage the crypttab should not contain an entry with an
    # encryption device indicated by UUID. For SLE15-SP1 this should be supported.
    #
    # Try to find the device when it was indicated by UUID
    #
    # @return [BlkDevice, nil] nil if the device is not found
    def find_device_by_uuid(_devicegraph)
      nil
    end

    # TODO: using old storage the crypttab should not contain an entry with an
    # encryption device indicated by LABEL. For SLE15-SP1 this should be supported.
    #
    # Try to find the device when it was indicated by LABEL
    #
    # @return [BlkDevice, nil] nil if the device is not found
    def find_device_by_label(_devicegraph)
      nil
    end

    # Try to find the device when it was indicaded by an udev name
    #
    # @param devicegraph [Devicegraph]
    # @return [BlkDevice, nil] nil if the device is not found
    def find_device_by_name(devicegraph)
      devicegraph.find_by_any_name(device)
    end
  end
end
