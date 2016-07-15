# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

module Yast
  module Storage
    # Base class to implement lists of devices.
    #
    # @see DisksList
    # @see PartitionsList
    # @see FilesystemsList
    class DevicesList
      include Enumerable
      extend Forwardable

      class << self
        attr_reader :device_class
        # Macro-style method to specify the class of the elements
        def list_of(klass)
          @device_class = klass
        end
        # rubocop:enable TrivialAccessors
      end

      def_delegators :@list, :each, :empty?, :length, :size

      def initialize(devicegraph, list: nil)
        @devicegraph = devicegraph
        @list = list || full_list
      end

      # Subset of the list matching some conditions
      #
      # Returns a list containing only the elements that meets some conditions.
      # Those conditions can be expressed as a list of attributes and values or
      # as a block that will be evaluated for every element in the list.
      #
      # When using a list of attributes, it automatically handles the situation
      # of libstorage objects raising an exception when the value of an
      # attribute is not found. Thus, example_partition.filesystem is considered
      # nil if the partition is not formatted, although default libstorage
      # behavior is to raise an exception instead of returning nil.
      #
      # It returns a list of the same time to allow chaining several calls
      # @example
      #   filtered = a_list.with(type: [type1, type2], name: nil)
      #   filtered.with { |element| element.id.start_with? "a" }
      #
      # @param attrs [Hash] attributes to filter by. The keys of the hash are
      #     method names, the values of the hash can be the desired value for
      #     the attribute or an Enumerable with several accepted values.
      # @return [DevicesList] subtype-preserving
      def with(attrs = {})
        new_list = list.select do |element|
          attrs.all? { |attr, value| match?(element, attr, value) }
        end
        new_list.select!(&Proc.new) if block_given?
        self.class.new(devicegraph, list: new_list)
      end

      def dup
        self.class.new(devicegraph, @list.dup)
      end

    protected

      attr_reader :devicegraph
      attr_accessor :list

      # Default collection of devices
      #
      # In many cases it can inferred by asking libstorage for the class
      # specified via .list_of. Sometimes is not possible and this method needs
      # to be redefined in the child class.
      #
      # return [Array]
      def full_list
        self.class.device_class.all(devicegraph).to_a
      end

      def match?(element, attr, value)
        begin
          real_value = element.send(attr)
        rescue ::Storage::WrongNumberOfChildren
          # Checking for something that is not there, which only matches if you
          # where indeed checking for nil
          return value.nil?
        end

        # First of all, check for exact match
        begin
          return true if real_value == value
        # Objects coming from SWIG perform strict type check for ==. Thus they
        # raise exceptions on type mismatch, instead of simply returning false
        rescue TypeError, ArgumentError
          return false unless value.is_a?(Enumerable)
        end

        # As a second option, check for collection
        value.is_a?(Enumerable) && value.include?(real_value)
      end
    end
  end
end
