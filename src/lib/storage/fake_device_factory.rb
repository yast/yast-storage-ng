#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
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
require "storage"
require_relative "abstract_device_factory.rb"
require "pp"

module Yast
  module Storage
    #
    # Factory class to generate faked devices in a device graph.
    # This is typically used with a YaML file.
    # Use the inherited load_yaml_file() to start the process.
    #
    class FakeDeviceFactory < AbstractDeviceFactory

      # Valid toplevel products of this factory
      VALID_TOPLEVEL  = [ "disk" ]

      # Valid hierarchy within the products of this factory.
      # This indicates the permitted children types for each parent.
      VALID_HIERARCHY =
        {
          "disk"       => ["partition_table", "partitions", "file_system"],
          "partitions" => ["partition", "free"],
          "partition"  => ["file_system"]
        }

      # Valid parameters for each product of this factory.
      # Sub-products are not listed here.
      VALID_PARAM =
        {
          "disk"            => ["name", "size"],
          "partition_table" => [],
          "partitions"      => [],
          "partition"       => ["size", "name", "type", "id", "mount_point", "label"],
          "file_system"     => [],
          "free"            => ["size"]
        }

      def initialize(devicegraph)
        super(devicegraph)
      end


      protected

      # Return a hash for the valid hierarchy of the products of this factory:
      # Each hash key returns an array (that might be empty) for the child
      # types that are valid below that key.
      #
      # @return [Hash<String, Array<String>>]
      #
      def valid_hierarchy
        VALID_HIERARCHY
      end

      # Return an array for valid toplevel products of this factory.
      #
      # @return [Array<String>] valid toplevel products
      #
      def valid_toplevel
        VALID_TOPLEVEL
      end

      # Return an hash of valid parameters for each product type of this
      # factory. This does not include sub-products, only the parameters that
      # are passed directly to each individual product.
      #
      # @return [Hash<String, Array<String> >]
      #
      def valid_param
        VALID_PARAM
      end

      #
      # Factory methods
      #
      # The AbstractDeviceFactory base class will collect all methods starting
      # with "create_" via Ruby introspection (methods()) and use them for
      # creating factory products.
      #
      
      # Factory method to create a disk.
      #
      # @return [::Storage::Disk]
      #
      def create_disk(parent, args)
        puts("#{__method__.to_s}( #{args} )")
        nil
      end

      def create_partition_table(parent, args)
        puts("#{__method__.to_s}( #{args} )")
        nil
      end

      def create_partition(parent, args)
        puts("#{__method__.to_s}( #{args} )")
        nil
      end

      def create_file_system(parent, args)
        puts("#{__method__.to_s}( #{args} )")
        nil
      end

      def create_free(parent, args)
        puts("#{__method__.to_s}( #{args} )")
        nil
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__  # Called direcly as standalone command? (not via rspec or require)
  fac = Yast::Storage::FakeDeviceFactory.new(nil)
  fac.load_yaml_file("fake-devicegraphs.yml")
end
