#!/usr/bin/env ruby
#
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

require "yast"
require "y2storage/planned_volume"
require "y2storage/proposal/proposed_partition"
require "y2storage/proposal/proposed_lv"

module Y2Storage
  # Collection of PlannedVolume elements
  #
  # Implements Enumerable and provides some extra methods to query the list of
  # PlannedVolume elements.
  #
  # In addition, it also stores which of the sizes defined by the volumes
  # (:min or :desired) should be used when trying to allocate them
  class PlannedVolumesList
    include Enumerable
    extend Forwardable
    include Yast::Logger

    # @return [Symbol] :min or :desired, size to use for the calculations
    attr_accessor :target

    def initialize(volumes = [], target: :desired)
      @volumes = volumes
      @target  = target
    end

    def_delegators :@volumes, :each, :empty?, :length, :size, :last

    def dup
      PlannedVolumesList.new(@volumes.dup, target: target)
    end

    # Deep copy of the collection
    #
    # Duplicates all the contained volumes, not only the container itself.
    #
    # @return [PlannedVolumesList]
    def deep_dup
      PlannedVolumesList.new(@volumes.map { |vol| vol.dup }, target: target)
    end

    # Deletes every element of the list for which block evaluates to true
    #
    # If no block is given, it returns an Enumerator
    #
    # @return [PlannedVolumesList] deleted elements
    def delete_if(&block)
      delegated = @volumes.delete_if(&block)
      delegated.is_a?(Array) ? PlannedVolumesList.new(delegated) : delegated
    end

    # Deletes the given volume
    #
    # @return [PlannedVolume] deleted volume
    def delete(vol)
      @volumes.delete(vol)
    end

    # Appends the given volume to the list. It returns the list itself,
    # so several appends may be chained together
    #
    # @param volume [PlannedVolume] element to add
    # @return [PlannedVolumesList]
    def push(volume)
      @volumes.push(volume)
      self
    end
    alias_method :<<, :push

    def ==(other)
      other.class == self.class && other.target == target && other.to_a == to_a
    end

    # Returns two lists, the first containing the elements for which the block
    # evaluates to true, the second containing the rest. Pretty much like
    # #partition but returning two volume lists instead of two arrays.
    #
    # If no block is given, it returns an Enumerator
    def split_by(&block)
      delegated = @volumes.partition(&block)
      if delegated.is_a?(Array)
        delegated.map { |l| PlannedVolumesList.new(l, target: target) }
      else
        # Enumerator
        delegated
      end
    end

    def proposed_partitions(lvm: false, target: nil)
      volumes = @volumes.dup
      volumes.reject!(&:can_live_on_logical_volume) if lvm
      volumes.reject!(&:reuse)
      volumes.map { |volume| ProposedPartition.new(volume: volume, target: target)}
    end

    def proposed_lvs(lvm: false, target: nil)
      return [] unless lvm
      volumes = @volumes.select(&:can_live_on_logical_volume)
      volumes.map { |volume| ProposedLv.new(volume: volume, target: target)}
    end

    def reused_partitions
      @volumes.map(&:reuse).compact
    end

    def to_s
      "#<PlannedVolumesList target=#{@target}, volumes=#{@volumes.map(&:to_s)}>"
    end
  end
end
