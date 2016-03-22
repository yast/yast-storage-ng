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
    class DevicesList
      include Enumerable
      extend Forwardable

      class << self
        attr_reader :device_class

        def list_of(klass)
          @device_class = klass
        end
      end

      def_delegators :@list, :each, :empty?, :length, :size

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

      def dup
        self.class.new(devicegraph, @list.dup)
      end

    protected
    
      attr_reader :devicegraph
      attr_accessor :list
      
      def full_list
        self.class.device_class.all(devicegraph).to_a
      end

      def match?(element, attr, value)
        begin
          real_value = element.send(attr)
        rescue ::Storage::WrongNumberOfChildren
          # Checking for something that is not there
          return false
        end

        begin
          return true if real_value == value
        rescue TypeError
          # Collections coming from SWIG perform strict type check for ==
          raise unless value.is_a?(Enumerable)
        end
        value.is_a?(Enumerable) && value.include?(real_value)
      end
    end
  end
end
