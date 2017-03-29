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

module Y2Storage
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
    # International System of Units (SI)
    SI_UNITS = ["KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"]
    UNLIMITED = "unlimited"

    attr_reader :size
    alias_method :to_i, :size
    alias_method :to_storage_value, :to_i

    # Accept Numbers, Strings, or DiskSize objects as initializers.
    #
    def initialize(size = 0)
      @size = if size.is_a?(Y2Storage::DiskSize)
        size.to_i
      elsif size.is_a?(::String)
        Y2Storage::DiskSize.parse(size).size
      else
        size.round
      end
    end

    #
    # Factory methods
    #
    class << self
      # Define an initializer method for each unit:
      # @see DiskSize::UNITS and DiskSize::SI_UNITS.
      #
      # Examples:
      #
      # DiskSize.MiB(10)  #=> new DiskSize of 10 MiB
      # DiskSize.MB(10)   #=> new DiskSize of 10 MB
      (UNITS + SI_UNITS).each do |unit|
        define_method(unit) { |v| DiskSize.new(calculate_bytes(v, unit)) }
      end

      def unlimited
        DiskSize.new(-1)
      end

      def zero
        DiskSize.new(0)
      end

      # Create a DiskSize from a parsed string.
      # @param str [String]
      # @param legacy_units [Boolean] if true, International System units
      # are considered as base 2 units, that is, MB is the same than MiB.
      #
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
      #   42 GB
      #   42GB
      #   512
      #   0.5 YiB (512 ZiB)
      #   1024MiB(1 GiB)
      #   unlimited
      #
      def parse(str, legacy_units: false)
        str = sanitize(str)
        return DiskSize.unlimited if str == UNLIMITED
        bytes = str_to_bytes(str, legacy_units: legacy_units)
        DiskSize.new(bytes)
      end

      alias_method :from_s, :parse
      alias_method :from_human_string, :parse

    private

      # Ignore everything added in parentheses, so we can also parse the output of #to_s
      def sanitize(str)
        str.gsub(/\(.*/, "").strip
      end

      def str_to_bytes(str, legacy_units: false)
        number = number(str).to_f
        unit = unit(str)
        return number if unit.empty?
        calculate_bytes(number, unit, legacy_units: legacy_units)
      end

      def number(str)
        number = str.scan(/^\d+\.?\d*/).first
        raise ArgumentError, "Bad number: #{str}" if number.nil?
        number
      end

      def unit(str)
        unit = str.gsub(number(str), "").strip
        if !unit.empty? && !(UNITS + SI_UNITS).include?(unit)
          raise ArgumentError, "Bad unit: #{str}"
        end
        unit
      end

      def calculate_bytes(number, unit, legacy_units: false)
        if UNITS.include?(unit)
          base = 1024
          exp = UNITS.index(unit)
        elsif SI_UNITS.include?(unit)
          base = 1000
          exp = SI_UNITS.index(unit) + 1
        else
          raise ArgumentError, "Bad unit: #{str}"
        end
        base = 1024 if legacy_units
        number * base**exp
      end
    end

    #
    # Operators
    #

    def +(other)
      return DiskSize.unlimited if any_operand_unlimited?(other)
      if other.is_a?(Numeric)
        DiskSize.new(@size + other)
      elsif other.respond_to?(:size)
        DiskSize.new(@size + other.size)
      else
        raise TypeError, "Unexpected #{other.class}; expected Numeric value or DiskSize"
      end
    end

    def -(other)
      return DiskSize.unlimited if any_operand_unlimited?(other)
      if other.is_a?(Numeric)
        DiskSize.new(@size - other)
      elsif other.respond_to?(:size)
        DiskSize.new(@size - other.size)
      else
        raise TypeError, "Unexpected #{other.class}; expected Numeric value or DiskSize"
      end
    end

    def %(other)
      return DiskSize.unlimited if any_operand_unlimited?(other)
      if other.is_a?(Numeric)
        DiskSize.new(@size % other)
      elsif other.respond_to?(:size)
        DiskSize.new(@size % other.size)
      else
        raise TypeError, "Unexpected #{other.class}; expected Numeric value or DiskSize"
      end
    end

    def *(other)
      if !other.is_a?(Numeric)
        raise TypeError, "Unexpected #{other.class}; expected Numeric value"
      end

      return DiskSize.unlimited if unlimited?
      DiskSize.new(@size * other)
    end

    def /(other)
      if !other.is_a?(Numeric)
        raise TypeError, "Unexpected #{other.class}; expected Numeric value"
      end

      return DiskSize.unlimited if unlimited?
      DiskSize.new(@size.to_f / other)
    end

    #
    # Other methods
    #

    def unlimited?
      @size == -1
    end

    def zero?
      @size == 0
    end

    # The Comparable mixin will get us operators < > <= >= == != with this
    def <=>(other)
      if other.respond_to?(:unlimited?) && other.unlimited?
        return unlimited? ? 0 : -1
      end
      return 1 if unlimited?
      return @size <=> other.size if other.respond_to?(:size)
      raise TypeError, "Unexpected #{other.class}; expected DiskSize"
    end

    # Result of rounding up the size to the next value that is divisible by
    # a given size. Returns the same value if it's already divisible.
    #
    # @param unit_size [DiskSize]
    # @return [DiskSize]
    def ceil(unit_size)
      new_size = floor(unit_size)
      new_size += unit_size if new_size != self
      new_size
    end

    # Result of rounding down the size to the previous value that is divisible
    # by a given size. Returns the same value if it's already divisible.
    #
    # @param unit_size [DiskSize]
    # @return [DiskSize]
    def floor(unit_size)
      return DiskSize.new(@size) unless can_be_rounded?(unit_size)

      modulo = @size % unit_size.to_i
      DiskSize.new(@size - modulo)
    end

    # Human-readable string. That is, represented in the biggest unit ("MiB",
    # "GiB", ...) that makes sense, even if it means losing some precision.
    #
    # @return [String]
    def to_human_string
      return "unlimited" if unlimited?
      size, unit = human_string_components
      format("%.2f %s", size, unit)
    end

    # exact value + human readable in parentheses (if the latter makes sense)
    def to_s
      return "unlimited" if unlimited?
      size1, unit1 = human_string_components
      size2, unit2 = string_components
      v1 = format("%.2f %s", size1, unit1)
      v2 = "#{size2 % 1 == 0 ? size2.to_i : size2} #{unit2}"
      # if both units are the same, just use exact value
      unit1 == unit2 ? v2 : "#{v2} (#{v1})"
    end

    def inspect
      return "<DiskSize <unlimited> (-1)>" if unlimited?
      "<DiskSize #{to_human_string} (#{to_i})>"
    end

    def pretty_print(*)
      print inspect
    end

  private

    # Return 'true' if either self or other is unlimited.
    #
    def any_operand_unlimited?(other)
      return true if unlimited?
      return other.respond_to?(:unlimited?) && other.unlimited?
    end

    # Checks whether makes sense to round the value to the given size
    def can_be_rounded?(unit_size)
      return false if unit_size.unlimited? || unit_size.zero? || unit_size.to_i == 1
      !unlimited? && !zero?
    end

    # Return numeric size and unit ("MiB", "GiB", ...) in human-readable form
    #
    # @return [Array] [size, unit]
    def human_string_components
      return [UNLIMITED, ""] if @size == -1

      unit_index = 0
      # prefer, 0.50 MiB over 512 KiB
      size2 = @size * 2

      while size2.abs >= 1024.0 && unit_index < UNITS.size - 1
        size2 /= 1024.0
        unit_index += 1
      end
      [size2 / 2.0, UNITS[unit_index]] # FIXME: Make unit translatable
    end

    # Return numeric size and unit ("MiB", "GiB", ...).
    # Unlike #human_string_components, always return the exact value.
    #
    # @return [Array] [size, unit]
    def string_components
      return [UNLIMITED, ""] if @size == -1

      unit_index = 0
      # allow half values
      size2 = @size * 2

      while size2 != 0 && (size2 % 1024) == 0 && unit_index < UNITS.size - 1
        size2 /= 1024
        unit_index += 1
      end
      [size2 / 2.0, UNITS[unit_index]]
    end
  end
end

#
#----------------------------------------------------------------------
#
if $PROGRAM_NAME == __FILE__ # Called direcly as standalone command? (not via rspec or require)
  size = Y2Storage::DiskSize.new(0)
  print "0 B: #{size} (#{size.size})\n"

  size = Y2Storage::DiskSize.new(511) - Y2Storage::DiskSize.new(512)
  print "too bad: 511 B - 512 B: #{size} (#{size.size})\n"

  size = Y2Storage::DiskSize.new(42)
  print "42 B: #{size} (#{size.size})\n"

  size = Y2Storage::DiskSize.new(512)
  print "512 B: #{size} (#{size.size})\n"

  size = Y2Storage::DiskSize.KiB(42)
  print "42 KiB: #{size} (#{size.size})\n"

  size = Y2Storage::DiskSize.MiB(43)
  print "43 MiB: #{size} (#{size.size})\n"

  size = Y2Storage::DiskSize.GiB(44)
  print "44 GiB: #{size} (#{size.size})\n"

  size = Y2Storage::DiskSize.TiB(45)
  print "45 TiB: #{size} (#{size.size})\n"

  size = Y2Storage::DiskSize.PiB(46)
  print "46 PiB: #{size} (#{size.size})\n"

  size = Y2Storage::DiskSize.EiB(47)
  print "47 EiB: #{size} (#{size.size})\n"

  size = Y2Storage::DiskSize.TiB(48 * (1024**5))
  print "Huge: #{size} (#{size.size})\n"

  size = Y2Storage::DiskSize.unlimited
  print "Hugest: #{size} (#{size.size})\n"

  size = Y2Storage::DiskSize.MiB(12) * 3
  print "3*12 MiB: #{size} (#{size.size})\n"

  size2 = size + Y2Storage::DiskSize.MiB(20)
  print "3*12+20 MiB: #{size2} (#{size2.size})\n"

  size2 /= 13
  print "(3*12+20)/7 MiB: #{size2} (#{size2.size})\n"

  print "#{size} < #{size2} ? -> #{size < size2}\n"
  print "#{size} > #{size2} ? -> #{size > size2}\n"
end
