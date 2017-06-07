# encoding: utf-8
#
# Copyright (c) [2017] SUSE LLC
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

require "y2storage/skip_list_value"

module Y2Storage
  # AutoYaST device skip rule
  #
  # @example Using a rule
  #   Disk = Struct.new(:size_k)
  #   disk = Disk.new(8192)
  #   rule = SkipListRule.new(:size_k, :less_than, 16384)
  #   rule.matches?(disk) #=> true
  #
  # @example Creating a rule from an AutoYaST profile hash
  #   hash = { "skip_key" => "size_k", "skip_if_less_than" => 16384,
  #     "skip_value" => 1024 }
  #   SkipListRule.from_profile_hash(hash)
  #
  class SkipListRule
    # @return [String] Name of the attribute to check when applying the rule
    attr_reader :key
    # @return [Symbol] Comparison (:less_than, :more_than and :equal_to)
    attr_reader :predicate
    # @return [String] Reference value
    attr_reader :raw_reference

    # It runs 0
    PREDICATES = {
      less_than: [Fixnum].freeze,
      more_than: [Fixnum].freeze,
      equal_to:  [Fixnum, Symbol, String].freeze
    }.freeze

    class << self
      # Creates a rule from an AutoYaST profile rule definition
      #
      # Let's consider the following AutoYaST rule:
      #
      #   <listentry>
      #     <skip_key>size_k</skip_key>
      #     <skip_value>1048576</skip_value> <!-- translated as string -->
      #     <skip_if_less_than config:type="boolean">true</skip_if_less_than>
      #   </listentry>
      #
      # @example Building a rule from a hash
      #   hash # => { "skip_key" => "size_k", "skip_value" => "1048756",
      #     "skip_if_less_than" => true }
      #   rule = SkipRule.new(hash)
      #   rule.predicate     #=> :less_than
      #   rule.raw_reference #=> "1048756"
      #   rule.key           #=> "size_k"
      def from_profile_rule(hash)
        predicate =
          if hash["skip_if_less_than"]
            :less_than
          elsif hash["skip_if_more_than"]
            :more_than
          else
            :equal_to
          end
        new(hash["skip_key"], predicate, hash["skip_value"])
      end
    end

    # Constructor
    #
    # @param key           [String] Name of the attribute to check when applying the rule
    # @param predicate     [Symbol,String] Comparison (:less_than, :more_than and :equal_to)
    # @param raw_reference [String] Reference value
    def initialize(key, predicate, raw_reference)
      @key = key
      @predicate = predicate
      @raw_reference = raw_reference
    end

    # Determines whether a disk matches the rule
    #
    # @param disk [Y2Storage::Disk] Disk
    # @return [Boolean] true if the disk matches the rule
    def matches?(disk)
      value_from_disk = value(disk)
      return false unless valid_class?(value_from_disk)
      send("match_#{predicate}", value_from_disk, cast_reference(raw_reference, value_from_disk.class))
    end

    # Returns the value to compare from the disk
    #
    # This method relies on SkipListValue which is able to gather
    # the required information from the disk.
    #
    # @see Y2Storage::SkipListValue
    def value(disk)
      Y2Storage::SkipListValue.new(disk).send(key)
    end

  private

    # Determines whether the predicate is applicable to the value
    #
    # @return [Boolean] true if it is applicable
    def valid_class?(value)
      PREDICATES[predicate].include?(value.class)
    end

    # Cast the reference value in order to do the comparison
    #
    # @param raw [String]
    # @return [String,Fixnum,Symbol] Converted reference value
    def cast_reference(raw, klass)
      if klass == Fixnum
        raw.to_i
      elsif klass == Symbol
        raw.respond_to?(:to_sym) ? raw.to_sym : :nothing
      else
        raw
      end
    end

    # less_than predicate
    #
    # @param value     [Fixnum] Value to compare
    # @param reference [Fixnum] Reference value
    # @return [Boolean] true if +value+ is less than +reference+.
    def match_less_than(value, reference)
      value < reference
    end

    # more_than predicate
    #
    # @param value     [Fixnum] Value to compare
    # @param reference [Fixnum] Reference value
    # @return [Boolean] true if +value+ is greater than +reference+.
    def match_more_than(value, reference)
      value > reference
    end

    # equal_to predicate
    #
    # @param value     [Fixnum] Value to compare
    # @param reference [Fixnum] Reference value
    # @return [Boolean] true if +value+ is equal to +reference+.
    def match_equal_to(value, reference)
      value == reference
    end
  end
end
