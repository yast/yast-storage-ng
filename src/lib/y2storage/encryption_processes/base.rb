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

require "yast"

require "abstract_method"

module Y2Storage
  module EncryptionProcesses
    # Base class to perform, through an EncryptionMethod, the creation of an encrypted device
    #
    # @note This is a base class. To really created an encrypted device use any
    # of its subclasses, which must defines an #encryption_type.
    class Base
      include Yast::Logger

      # Whether the process was used for the given encryption device
      #
      # @param _encryption [Y2Storage::Encryption] the encryption device to check
      # @return [Boolean] true if the given device looks to be encrypted with
      # the process; false otherwise
      def self.used_for?(_encryption)
        false
      end

      # Whether the process can be executed in the current system
      #
      # @see EncryptionMethod#available?
      #
      # @return [Boolean]
      def self.available?
        true
      end

      # Constructor
      #
      # @param method [Y2Storage::EncryptionMethod]
      def initialize(method)
        @method = method
      end

      # @return [EncryptionMethod] the encryption method using the process
      attr_reader :method

      # Creates an encryption layer over the given block device
      #
      # @param blk_device [Y2Storage::BlkDevice]
      # @param dm_name [String]
      def create_device(blk_device, dm_name)
        enc = blk_device.create_encryption(dm_name || "", encryption_type)
        enc.encryption_process = self
        enc
      end

      # Returns the encryption type to be used
      #
      # This method must be defined by derived class.
      #
      # @return [Y2Storage::EncryptionType]
      abstract_method :encryption_type
    end
  end
end
