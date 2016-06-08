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
    # Disk sizes are stored internally in bytes. Negative values are
    # allowed in principle but the special value -1 is reserved to mean
    # 'unlimited'.
    #
    class DiskSize
      include Comparable

      UNITS = ["B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"]
      UNLIMITED = "unlimited"

      attr_accessor :size_b

      # Accept Numbers, Strings, or DiskSize objects as initializers.
      #
      def initialize(size = 0)
        if size.kind_of?(Yast::Storage::DiskSize)
          @size_b = size.size
        elsif size.kind_of?(String)
          @size_b = Yast::Storage::DiskSize.parse(size).size
        else
          @size_b = size.round
        end
      end

      def size=(s)
        self.size_b = s
      end

      def size
        self.size_b
      end

      #
      # Factory methods
      #
      class << self
        # rubocop:disable Style/MethodName
        def B(size)
          DiskSize.new(size)
        end

        def KiB(size)
          DiskSize.new(size * 1024)
        end

        def MiB(size)
          DiskSize.new(size * (1024**2))
        end

        def GiB(size)
          DiskSize.new(size * (1024**3))
        end

        def TiB(size)
          DiskSize.new(size * (1024**4))
        end

        def PiB(size)
          DiskSize.new(size * (1024**5))
        end

        def EiB(size)
          DiskSize.new(size * (1024**6))
        end

        def ZiB(size)
          DiskSize.new(size * (1024**7))
        end

        def YiB(size)
          DiskSize.new(size * (1024**8))
        end
        # rubocop:enable Style/MethodName

        def unlimited
          DiskSize.new(-1)
        end

        def zero
          DiskSize.new(0)
        end

        # Create a DiskSize from a parsed string.
        # Valid format:
        #
        #   NUMBER [UNIT] [(COMMENT)] | unlimited
        #
        # A non-negative floating point number, optionally followed by a binary unit (e.g. 'GiB'),
        # optionally followed by a comment in parentheses (which is ignored).
        # Alternatively, the string 'unlimited' represents an infinite size.
        #
        # If UNIT is missing, 'B' (bytes) is assumed.
        #
        # Examples:
        #   42 GiB
        #   42.00  GiB
        #   512
        #   0.5 YiB (512 ZiB)
        #   unlimited
        #
        # Invalid:
        #   42 GB    (supporting binary units only)
        #
        def parse(str)
          # ignore everything added in parentheses, so we can also parse the output of #to_s_ex
          str.gsub!(/\(.*/, "")
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

        # Return the unit exponent for any of the known binary units ("KiB",
        # "MiB", ...). The base of this exponent is 1024. The base unit is KiB.
        #
        def unit_exponent(unit)
          # rubocop:disable Style/AndOr
          UNITS.index(unit) or raise ArgumentError, "expected one of #{UNITS}"
          # rubocop:enable Style/AndOr
        end

        # Return the unit multiplier for any of the known binary units ("KiB",
        # "MiB", ...). The base unit is KiB.
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
          DiskSize.new(@size_b + other)
        elsif other.respond_to?(:size)
          DiskSize.new(@size_b + other.size)
        else
          raise TypeError, "Unexpected #{other.class}; expected Numeric value or DiskSize"
        end
      end

      def -(other)
        return DiskSize.unlimited if any_operand_unlimited?(other)
        if other.is_a?(Numeric)
          DiskSize.new(@size_b - other)
        elsif other.respond_to?(:size)
          DiskSize.new(@size_b - other.size)
        else
          raise TypeError, "Unexpected #{other.class}; expected Numeric value or DiskSize"
        end
      end

      def *(other)
        if other.is_a?(Numeric)
          return DiskSize.unlimited if unlimited?
          DiskSize.new(@size_b * other)
        else
          raise TypeError, "Unexpected #{other.class}; expected Numeric value"
        end
      end

      def /(other)
        if other.is_a?(Numeric)
          return DiskSize.unlimited if unlimited?
          DiskSize.new(@size_b.to_f / other)
        else
          raise TypeError, "Unexpected #{other.class}; expected Numeric value"
        end
      end

      #
      # Other methods
      #

      def unlimited?
        @size_b == -1
      end

      def zero?
        @size_b == 0
      end

      # The Comparable mixin will get us operators < > <= >= == != with this
      def <=>(other)
        if other.respond_to?(:unlimited?) && other.unlimited?
          return unlimited? ? 0 : -1
        end
        return 1 if unlimited?
        return @size_b <=> other.size if other.respond_to?(:size)
        raise TypeError, "Unexpected #{other.class}; expected DiskSize"
      end

      # Return numeric size and unit ("MiB", "GiB", ...) in human-readable form
      # @return [Array] [size, unit]
      def to_human_readable
        return [UNLIMITED, ""] if @size_b == -1

        unit_index = 0
        # prefer, 0.50 MiB over 512 KiB
        size2 = @size_b * 2

        while size2.abs >= 1024.0 && unit_index < UNITS.size - 1
          size2 /= 1024.0
          unit_index += 1
        end
        [size2 / 2.0, UNITS[unit_index]]  # FIXME: Make unit translatable
      end

      # Return numeric size and unit ("MiB", "GiB", ...) in human-readable form
      # But unlike #to_human_readable, return the exact value.
      # @return [Array] [size, unit]
      def to_human_readable_ex
        return [UNLIMITED, ""] if @size_b == -1

        unit_index = 0
        # allow half values
        size2 = @size_b * 2

        while size2 != 0 && (size2 % 1024) == 0 && unit_index < UNITS.size - 1
          size2 /= 1024
          unit_index += 1
        end
        [size2 / 2.0, UNITS[unit_index]]
      end

      def to_s
        return "unlimited" if unlimited?
        size, unit = to_human_readable
        format("%.2f %s", size, unit)
      end

      # exact value + human readable in parentheses
      def to_s_ex
        return "unlimited" if unlimited?
        size1, unit1 = to_human_readable
        size2, unit2 = to_human_readable_ex
        v1 = format("%.2f %s", size1, unit1)
        v2 = "#{size2 % 1 == 0 ? size2.to_i : size2} #{unit2}"
        # if both units are the same, just use exact value
        unit1 == unit2 ? v2 : "#{v2} (#{v1})"
      end

      def inspect
        return "<DiskSize <unlimited> (-1)>" if unlimited?
        "<DiskSize #{self} (#{size_b})>"
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
  size = Yast::Storage::DiskSize.new(0)
  print "0 B: #{size} (#{size.size})\n"

  size = Yast::Storage::DiskSize.new(511) - Yast::Storage::DiskSize.new(512)
  print "too bad: 511 B - 512 B: #{size} (#{size.size})\n"

  size = Yast::Storage::DiskSize.new(42)
  print "42 B: #{size} (#{size.size})\n"

  size = Yast::Storage::DiskSize.new(512)
  print "512 B: #{size} (#{size.size})\n"

  size = Yast::Storage::DiskSize.KiB(42)
  print "42 KiB: #{size} (#{size.size})\n"

  size = Yast::Storage::DiskSize.MiB(43)
  print "43 MiB: #{size} (#{size.size})\n"

  size = Yast::Storage::DiskSize.GiB(44)
  print "44 GiB: #{size} (#{size.size})\n"

  size = Yast::Storage::DiskSize.TiB(45)
  print "45 TiB: #{size} (#{size.size})\n"

  size = Yast::Storage::DiskSize.PiB(46)
  print "46 PiB: #{size} (#{size.size})\n"

  size = Yast::Storage::DiskSize.EiB(47)
  print "47 EiB: #{size} (#{size.size})\n"

  size = Yast::Storage::DiskSize.TiB(48 * (1024**5))
  print "Huge: #{size} (#{size.size})\n"

  size = Yast::Storage::DiskSize.unlimited
  print "Hugest: #{size} (#{size.size})\n"

  size = Yast::Storage::DiskSize.MiB(12) * 3
  print "3*12 MiB: #{size} (#{size.size})\n"

  size2 = size + Yast::Storage::DiskSize.MiB(20)
  print "3*12+20 MiB: #{size2} (#{size2.size})\n"

  size2 /= 13
  print "(3*12+20)/7 MiB: #{size2} (#{size2.size})\n"

  print "#{size} < #{size2} ? -> #{size < size2}\n"
  print "#{size} > #{size2} ? -> #{size > size2}\n"
end
