#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015-2017] SUSE LLC
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
require "y2storage/blk_device"

module Y2Storage
  module Planned
    # Abstract base class for the different devices templates in the
    # Planned namespace.
    #
    # Most classes in the {Planned} namespace represent an specification
    # of a given device that must be created in a devicegraph (thus, finally in
    # the system) by the storage proposal or by AutoYaST. That specification is,
    # of course, less concrete than the real device object.
    #
    # Those templates clases inherit from this and implement most of the
    # functionality and properties by composition, including several of the
    # mixins defined in the {Planned} namespace.
    class Device
      include Yast::Logger

      # @return [String] device name of an existing device to reuse for this
      #   purpose. As a result, some of the others attributes could be ignored.
      attr_accessor :reuse

      def to_s
        attrs = self.class.to_string_attrs.map do |attr|
          value = send(attr)
          value = "nil" if value.nil?
          "#{attr}=#{value}"
        end
        "#<#{self.class} " + attrs.join(", ") + ">"
      end

      def ==(other)
        other.class == self.class && other.internal_state == internal_state
      end

      def self.to_string_attrs
        [:reuse]
      end

      # Returns the (possibly processed) device to be used for the planned
      # device.
      #
      # FIXME: temporary API. It should be improved.
      def final_device!(plain_device)
        plain_device.encrypted? ? plain_device.encryption : plain_device
      end

      # Finds the device to reuse and sets its properties to match
      # the planned device.
      #
      # @param devicegraph [Devicegraph] Device graph to adjust
      def reuse!(devicegraph)
        dev = device_to_reuse(devicegraph)
        reuse_device!(dev) if dev
      end

      # Whether this planned device is expected to reuse an existing one
      def reuse?
        !(reuse.nil? || reuse.empty?)
      end

    protected

      def reuse_device!(dev)
        log.info "Reusing #{reuse} (#{dev.inspect}) for #{self}"
      end

      def device_to_reuse(devicegraph)
        return nil unless reuse?
        BlkDevice.find_by_name(devicegraph, reuse)
      end

      def internal_state
        instance_variables.sort.map { |v| instance_variable_get(v) }
      end
    end
  end
end
