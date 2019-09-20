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

require "y2storage/encryption_processes/luks1"
require "y2storage/encryption_processes/swap"
require "y2storage/encryption_processes/pervasive"

module Y2Storage
  # YaST provides different Encryption Methods to encrypt a block device. Not to be confused with the
  # encryption type ({EncryptionType} class) that represents the encryption technology used underneath
  # (e.g., LUKS1, PLAIN, etc).
  #
  # An Encryption Method is identified by a name and it encapsulates a set of steps to encrypt the
  # device.
  #
  # Users of this class cannot create new Encryption Methods. This class offers a catalog of possible
  # Encryption Methods, see {EncryptionMethod.all}.
  #
  # @example
  #
  #   method = EncryptionMethod.all.first
  #   method = EncryptionMethod.available.first
  #   method = EncryptionMethod.find(:luks1)
  #   method = EncryptionMethod.find(:random_swap)
  #   method = EncryptionMethod.new #=> error, private method
  class EncryptionMethod
    include Yast::I18n
    extend Yast::I18n

    # Constructor
    #
    # @param id [Symbol]
    # @param label [String]
    # @param process_class [#new] class name of the encryption process (e.g.,
    #   EncryptionProcesses::Luks1)
    def initialize(id, label, process_class)
      textdomain "storage"

      @id = id
      @label = label
      @process_class = process_class
    end

    LUKS1 = new(
      :luks1, N_("Regular LUKS1"), EncryptionProcesses::Luks1
    )
    PERVASIVE_LUKS2 = new(
      :pervasive_luks2, N_("Pervasive Volume Encryption"), EncryptionProcesses::Pervasive
    )
    RANDOM_SWAP = new(
      :random_swap, N_("Random Swap"), EncryptionProcesses::Swap
    )

    ALL = [LUKS1, PERVASIVE_LUKS2, RANDOM_SWAP].freeze
    private_constant :ALL

    class << self
      # Make sure only the class itself can create objects, which can be used through .all, .find, and
      # .for_device
      private :new

      # Sorted list of all possible encryption methods
      #
      # @return [Array<Y2Storage::EncryptionMethod>]
      def all
        ALL.dup
      end

      # Sorted list of all encryption methods that can be used in this system
      #
      # @return [Array<Y2Storage::EncryptionMethod>]
      def available
        all.select(&:available?)
      end

      # Looks for the encryption method used for the given encryption device
      #
      # @param encryption [Y2Storage::Encryption]
      # @return [Y2Storage::EncryptionMethod, nil]
      def for_device(encryption)
        all.find { |m| m.used_for?(encryption) }
      end

      # Looks for the encryption method by its symbol representation
      #
      # @param value [#to_sym]
      # @return [Y2Storage::EncryptionMethod, nil] the encryption method found if any; nil otherwise
      def find(value)
        all.find { |i| i.is?(value) }
      end
    end

    # @return [Symbol] name to represent the encryption method (e.g., :luks1, :random_swap)
    attr_reader :id
    alias_method :to_sym, :id

    # Localized label to represent the encryption method
    #
    # @return [String] very likely, a frozen string
    def to_human_string
      _(@label)
    end

    # Compares two encryption methods
    #
    # @param other [Y2Storage::EncryptionMethod]
    # @return [Boolean] true if compared encryption methods have the same class and id; false if not
    def ==(other)
      other.class == self.class && other.id == id
    end

    alias_method :eql?, :==

    # Whether the given value matches with the symbol representation (id) of the
    # encryption method
    #
    # @param value [#to_sym]
    # @return [Boolean]
    def is?(value)
      id == value.to_sym
    end

    # Whether the encryption method was used for the given encryption device
    #
    # @param encryption [Y2Storage::Encryption]
    # @return [Boolean]
    def used_for?(encryption)
      process_class.used_for?(encryption)
    end

    # Whether the encryption method can be used in this system
    #
    # @return [Boolean]
    def available?
      process_class.available?
    end

    # Whether the encryption method is useful only for swap
    #
    # Some encryption methods are mainly useful for encrypting swap disks since they produdce a new key
    # on every boot cycle.
    #
    # @return [Boolean]
    def only_for_swap?
      process_class.only_for_swap?
    end

    # Creates an encryption device for the given block device
    #
    # @param blk_device [Y2Storage::BlkDevice]
    # @param dm_name [String]
    # @return [Y2Storage::Encryption]
    def create_device(blk_device, dm_name)
      process_class.new(self).create_device(blk_device, dm_name)
    end

    private

    # @return [Y2Storage::EncryptionProcesses] the process used by the method to perform the encryption
    attr_accessor :process_class
  end
end
