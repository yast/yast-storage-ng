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

# This file can be invoked separately for minimal testing.

module Yast
  module Storage
    #
    # Class to handle disk sizes in the MB/GB/TB range with readable output.
    #
    class DiskSize
      include Comparable

      UNITS = ["kiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"]
      UNLIMITED = "unlimited"

      attr_accessor :size_k

      def initialize(size_k = 0)
        @size_k = size_k.round
      end

      #
      # Factory methods
      #
      class << self
        # rubocop:disable Style/MethodName
        def kiB(size)
          DiskSize.new(size)
        end

        def MiB(size)
          DiskSize.new(size * 1024)
        end

        def GiB(size)
          DiskSize.new(size * (1024**2))
        end

        def TiB(size)
          DiskSize.new(size * (1024**3))
        end

        def PiB(size)
          DiskSize.new(size * (1024**4))
        end

        def EiB(size)
          DiskSize.new(size * (1024**5))
        end

        def ZiB(size)
          DiskSize.new(size * (1024**6))
        end

        def YiB(size)
          DiskSize.new(size * (1024**7))
        end
        # rubocop:enable Style/MethodName

        def unlimited
          DiskSize.new(-1)
        end

        def zero
          DiskSize.new(0)
        end

        # Create a DiskSize from a parsed string.
        # Valid formats:
        #   42 GiB
        #   42.00  GiB
        #   42          (=> 42 kiB)
        #   unlimited   (=> -1 == unlimited)
        #
        # Invalid:
        #   42 GB    (supporting binary units only)
        #
        def parse(str)
          str.strip!
          return DiskSize.unlimited if str == UNLIMITED
          size_str, unit = str.split(/\s+/)
          raise ArgumentError, "Bad number: #{size_str}" if size_str !~ /^\d+\.?\d*$/
          size = size_str.to_f
          return DiskSize.new(size) if unit.nil?
          DiskSize.new(size * unit_multiplier(unit))
        end

        alias_method :from_s, :parse
        alias_method :from_human_readable, :parse

        # Return the unit exponent for any of the known binary units ("kiB",
        # "MiB", ...). The base of this exponent is 1024. The base unit is kiB.
        #
        def unit_exponent(unit)
          # rubocop:disable Style/AndOr
          UNITS.index(unit) or raise ArgumentError, "expected one of #{UNITS}"
          # rubocop:enable Style/AndOr
        end

        # Return the unit multiplier for any of the known binary units ("kiB",
        # "MiB", ...). The base unit is kiB.
        #
        def unit_multiplier(unit)
          1024**unit_exponent(unit)
        end
      end

      #
      # Operators
      #

      def +(other)
        return DiskSize.unlimited if any_operand_unlimited?(other)
        if other.is_a?(Numeric)
          DiskSize.new(@size_k + other)
        elsif other.respond_to?(:size_k)
          DiskSize.new(@size_k + other.size_k)
        else
          raise TypeError, "Unexpected #{other.class}; expected Numeric value or DiskSize"
        end
      end

      def -(other)
        return DiskSize.unlimited if any_operand_unlimited?(other)
        if other.is_a?(Numeric)
          DiskSize.new(@size_k - other)
        elsif other.respond_to?(:size_k)
          DiskSize.new(@size_k - other.size_k)
        else
          raise TypeError, "Unexpected #{other.class}; expected Numeric value or DiskSize"
        end
      end

      def *(other)
        if other.is_a?(Numeric)
          return DiskSize.unlimited if unlimited?
          DiskSize.new(@size_k * other)
        else
          raise TypeError, "Unexpected #{other.class}; expected Numeric value"
        end
      end

      def /(other)
        if other.is_a?(Numeric)
          return DiskSize.unlimited if unlimited?
          DiskSize.new(@size_k.to_f / other)
        else
          raise TypeError, "Unexpected #{other.class}; expected Numeric value"
        end
      end

      #
      # Other methods
      #

      def unlimited?
        size_k == -1
      end

      def zero?
        size_k == 0
      end

      # The Comparable mixin will get us operators < > <= >= == != with this
      def <=>(other)
        if other.respond_to?(:unlimited?) && other.unlimited?
          return unlimited? ? 0 : -1
        end
        return 1 if unlimited?
        return @size_k <=> other.size_k if other.respond_to?(:size_k)
        raise TypeError, "Unexpected #{other.class}; expected DiskSize"
      end

      # Return numeric size and unit ("MiB", "GiB", ...) in human-readable form
      # @return [Array] [size, unit]
      def to_human_readable
        return [UNLIMITED, ""] if size_k == -1

        unit_index = 0
        size = @size_k.to_f

        while size >= 1024.0 && unit_index < UNITS.size - 1
          size /= 1024.0
          unit_index += 1
        end
        [size, UNITS[unit_index]]  # FIXME: Make unit translatable
      end

      def to_s
        return "unlimited" if unlimited?
        size, unit = to_human_readable
        format("%.2f %s", size, unit)
      end

      def inspect
        return "<DiskSize <unlimited> (-1)>" if unlimited?
        "<DiskSize #{self} (#{size_k} kiB)>"
      end

      def pretty_print(*)
        print "#{inspect}"
      end

      private

      # Return 'true' if either self or other is unlimited.
      #
      def any_operand_unlimited?(other)
        return true if unlimited?
        return other.respond_to?(:unlimited?) && other.unlimited?
      end
    end
  end
end

#
#----------------------------------------------------------------------
#
if $PROGRAM_NAME == __FILE__  # Called direcly as standalone command? (not via rspec or require)
  size = Yast::Storage::DiskSize.new(42)
  print "42 kiB: #{size} (#{size.size_k} kiB)\n"

  size = Yast::Storage::DiskSize.MiB(43)
  print "43 MiB: #{size} (#{size.size_k} kiB)\n"

  size = Yast::Storage::DiskSize.GiB(44)
  print "44 GiB: #{size} (#{size.size_k} kiB)\n"

  size = Yast::Storage::DiskSize.TiB(45)
  print "45 TiB: #{size} (#{size.size_k} kiB)\n"

  size = Yast::Storage::DiskSize.PiB(46)
  print "46 PiB: #{size} (#{size.size_k} kiB)\n"

  size = Yast::Storage::DiskSize.EiB(47)
  print "47 EiB: #{size} (#{size.size_k} kiB)\n"

  size = Yast::Storage::DiskSize.TiB(48 * (1024**5))
  print "Huge: #{size} (#{size.size_k} kiB)\n"

  size = Yast::Storage::DiskSize.MiB(12) * 3
  print "3*12 MiB: #{size} (#{size.size_k} kiB)\n"

  size2 = size + Yast::Storage::DiskSize.MiB(20)
  print "3*12+20 MiB: #{size2} (#{size2.size_k} kiB)\n"

  size2 /= 13
  print "(3*12+20)/7 MiB: #{size2} (#{size2.size_k} kiB)\n"

  print "#{size} < #{size2} ? -> #{size < size2}\n"
  print "#{size} > #{size2} ? -> #{size > size2}\n"
end
