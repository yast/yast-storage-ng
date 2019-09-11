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

require "y2storage/encryption_processes/luks1"
require "y2storage/encryption_processes/swap"
require "y2storage/encryption_processes/pervasive"

module Y2Storage
  # Class representing each one of the mechanisms YaST can use to encrypt a
  # block device.
  #
  # Not to be confused with {EncryptionType} that represents the encryption
  # technology used underneath.
  #
  # Each encryption method has a name and encapsulates the corresponding
  # steps and encryption properties (e.g. the type).
  class EncryptionMethod
    include Yast::I18n
    extend Yast::I18n

    # Constructor
    def initialize(id, label, process_class)
      textdomain "storage"

      @id = id
      @label = label
      @process_class = process_class
    end

    LUKS1 = new(
      :luks1, N_("Regular LUKS1"), EncryptionProcesses::Luks1
    )
    RANDOM_SWAP = new(
      :random_swap, N_("Random Swap"), EncryptionProcesses::Swap
    )
    PERVASIVE_LUKS2 = new(
      :pervasive_luks2, N_("Pervasive Volume Encryption"), EncryptionProcesses::Pervasive
    )

    ALL = [LUKS1, PERVASIVE_LUKS2, RANDOM_SWAP].freeze
    private_constant :ALL

    # Sorted list of all possible settings
    def self.all
      ALL.dup
    end

    def self.for_device(encryption)
      all.find { |m| m.used_for?(encryption) }
    end

    def self.find(value)
      all.find { |i| i.is?(value) }
    end

    def self.available
      all.select { |m| m.available? }
    end

    # @return [Symbol]
    attr_reader :id
    alias_method :to_sym, :id

    # Localized label to represent the encryption method
    #
    # @return [String] very likely, a frozen string
    def to_human_string
      _(@label)
    end

    def ==(other)
      other.class == self.class && other.id == id
    end

    alias_method :eql?, :==

    def is?(value)
      id == value.to_sym
    end

    def used_for?(encryption)
      process_class.used_for?(encryption)
    end

    def available?
      process_class.available?
    end

    def create_device(blk_device, dm_name)
      process_class.new(self).create_device(blk_device, dm_name)
    end

    private

    attr_accessor :process_class
  end
end
