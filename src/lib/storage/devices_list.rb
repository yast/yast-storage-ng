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

module Yast
  module Storage
    class DevicesList
      include Enumerable

      class << self
        attr_accessor :device_class
        attr_accessor :default_delegate

        def list_of(klass)
          self.device_class = klass
        end

        def by_default_delegate_to(list)
          self.default_delegate = list
        end
      end

      attr_reader :devicegraph

      def initialize(devicegraph, list: nil)
        @devicegraph = devicegraph
        @list = list || full_list
      end

      def with(attrs = {})
        new_list = list.select do |element|
          attrs.all? { |attr, value| match?(element, attr, value) }
        end
        if block_given?
          new_list.select!(&Proc.new)
        end
        self.class.new(devicegraph, list: new_list)
      end

      def each(&block)
        @list.each(&block)
      end

      def dup
        self.class.new(devicegraph, @list.dup)
      end

      # Returns true if the list contains no elements
      #
      # @return [Boolean]
      def empty?
        list.empty?
      end

      # Number of elements in the list
      #
      # @return [Fixnum]
      def length
        list.length
      end
      alias_method :size, :length

      def method_missing(meth, *args, &block)
        delegate_list = self.class.default_delegate
        if delegate_list
          delegate_list.send(meth, *args, &block)
        else
          super
        end
      end

    protected
    
      attr_accessor :list
      
      def full_list
        self.class.device_class.all(devicegraph).to_a
      end

      def match?(element, attr, value)
        real_value = element.send(attr)
        return true if real_value == value
        value.is_a?(Array) && value.include?(real_value)
      end
    end
  end
end
