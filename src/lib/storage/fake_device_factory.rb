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
require "yaml"
require "pp"

module Yast
  module Storage
    #
    # Factory class to generate faked devices in a device graph.
    # This is typically used with a YaML file.
    #
    class FakeDeviceFactory
      include Yast::Logger

      class HierarchyError < RuntimeError
      end

      # Allowed toplevel products of this factory
      TOPLEVEL  = [ "disk" ]

      # Hierarchy within the products of this factory
      HIERARCHY =
        {
          "disk"       => ["partition_table", "partitions", "file_system"],
          "partitions" => ["partition", "free"],
          "partition"  => ["file_system"]
        }

      # Permitted parameters for each product of this factory.
      # Sub-products are not listed here.
      PARAM =
        {
          "disk"            => ["name", "size"],
          "partition_table" => [],
          "partitions"      => [],
          "partition"       => ["size", "name", "type", "id", "mount_point", "label"],
          "file_system"     => [],
          "free"            => ["size"]
        }

      attr_reader :devicegraph

      def initialize(devicegraph)
        @devicegraph = devicegraph
        @factory_methods_cache  = nil
        @factory_products_cache = nil
      end

      # Read a YaML file and build a fake device tree from it.
      #
      # @param filename name of the YaML file
      #
      def load_yaml_file(filename)
        begin
          File.open(filename) { |file| YAML.load_documents(file) { |doc| build_tree(doc) } }
        rescue SystemCallError => ex
          log.error("#{ex}")
          raise
        end
      end

      def build_tree(obj)
        name, content = break_up_hash(obj)
        raise HierarchyError, "Unexpected toplevel object #{name}" unless TOPLEVEL.include?(name)
        build_tree_recursive(name, content)
      end

      def build_tree_recursive(name, content)
        # puts("build_tree_recursive #{name}")
        raise HierarchyError, "Don't know how to create a #{name}" unless factory_products.include?(name)

        case content
        when Hash
          # Check if all the parameters we got belong to this factory product
          check_param(name, content.keys)

          # Split up pure parameters and sub-product descriptions
          sub_prod = content.select{ |k,v|  factory_products.include?(k) }
          param    = content.select{ |k,v| !factory_products.include?(k) }

          # Create the factory product itself: Call the corresponding create_ method
          create_method = "create_#{name}".to_sym
          self.send(create_method, param)

          # Create any sub-objects of the factory product
          sub_prod.each do |product, product_content|
            build_tree_recursive(product, product_content)
          end
        when Array
          parent = name
          content.each do |element|
            if element.is_a?(Hash)
              child_name, child_content = break_up_hash(element)
              check_hierarchy(parent, child_name)
              build_tree_recursive(child_name, child_content)
            else
              raise TypeError, "Expected Hash, not #{element}"
            end
          end
        else
          create_method = "create_#{name}".to_sym
          self.send(create_method, content)
        end
      end

      # Factory method to create a disk.
      #
      def create_disk(args)
        puts("#{__method__.to_s}( #{args} )")
      end

      def create_partition_table(args)
        puts("#{__method__.to_s}( #{args} )")
      end

      def create_partitions(args)
        puts("#{__method__.to_s}( #{args} )")
      end

      def create_partition(args)
        puts("#{__method__.to_s}( #{args} )")
      end

      def create_file_system(args)
        puts("#{__method__.to_s}( #{args} )")
      end

      def create_free(args)
        puts("#{__method__.to_s}( #{args} )")
      end

      private

      # Return the factory methods of this factory: All methods that start with
      # "create_".
      #
      # @return [Array<Symbol>] create methods
      #
      def factory_methods
        @factory_methods_cache ||= methods.select { |m| m =~ /^create_/ }
      end

      # Return the products this factory can create. This is derived from the
      # factory methods minus the "create_" prefix.
      #
      # @return [Array<String>] product names
      #
      def factory_products
        @factory_products_cache ||= factory_methods.map { |m| m.to_s.gsub(/^create_/, "") }
      end

      # Make sure 'obj' is a hash with a single key and break it up into that
      # key and the content. Raise an exception if this is some other object.
      #
      # @param obj [Hash]
      # @return [String, Object] hash key and hash content
      # 
      def break_up_hash(obj)
        name = obj.keys.first.to_s
        raise HierarchyError, "Expected hash, not #{obj}" unless obj.is_a?(Hash)
        raise HierarchyError, "Expected exactly one key in #{name}" if obj.size != 1
        content = obj[name]
        [name, content]
      end

      # Check if all the parameters in "param"_are expected for factory product
      # "name".
      #
      # @param name  [String] factory product name
      # @param param [Array<Symbol> or Array<String>] parameters (hash keys)
      #
      def check_param(name, param)
        expected = PARAM[name]
        expected += HIERARCHY[name] if HIERARCHY.include?(name)
        param.each do |key|
          raise "ArgumentError", "Unexpected parameter #{key} in #{name}" unless expected.include?(key.to_s)
        end
      end

      # Check if 'child' is a valid child of 'parent'.
      # Raise an exception if not.
      #
      # @param parent [String] name of parent factory product
      # @param child  [String] name of child  factory product
      #
      def check_hierarchy(parent, child)
        if !HIERARCHY[parent].include?(child)
          raise HierarchyError, "Unexpected child #{child_name} for #{parent}"
        end
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__  # Called direcly as standalone command? (not via rspec or require)
  fac = Yast::Storage::FakeDeviceFactory.new(nil)
  fac.load_yaml_file("fake-devicegraphs.yml")
end
