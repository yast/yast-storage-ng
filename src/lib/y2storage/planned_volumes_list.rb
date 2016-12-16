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

    def_delegators :@volumes, :each, :empty?, :length, :size

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

    # Total sum of all desired or min sizes of volumes (according to #target)
    #
    # This tries to avoid an 'unlimited' result:
    # If a the desired size of any volume is 'unlimited',
    # its minimum size is taken instead. This gives a more useful sum in the
    # very common case that any volume has an 'unlimited' desired size.
    #
    # If the optional argument "rounding" is used, the size of every volume will
    # be rounded up. # @see DiskSize#ceil
    #
    # @param rounding [DiskSize, nil]
    # @return [DiskSize] sum of desired/min sizes in @volumes
    def target_disk_size(rounding: nil)
      rounding ||= DiskSize.new(1)
      @volumes.reduce(DiskSize.zero) { |sum, vol| sum + vol.min_valid_disk_size(target).ceil(rounding) }
    end

    # Total sum of all current max sizes of volumes
    #
    # If the optional argument "rounding" is used, the size of every volume will
    # be rounded up. # @see DiskSize#ceil
    #
    # @param rounding [DiskSize, nil]
    # @return [DiskSize]
    def max_disk_size(rounding: nil)
      rounding ||= DiskSize.new(1)
      @volumes.reduce(DiskSize.zero) { |sum, vol| sum + vol.max_disk_size.ceil(rounding) }
    end

    # Total sum of all current sizes of volumes
    #
    # @return [DiskSize] sum of sizes in @volumes
    def total_disk_size
      @volumes.reduce(DiskSize.zero) { |sum, vol| sum + vol.disk_size }
    end

    # Total sum of all current reserved sizes of volumes
    #
    # Similar to #total_disk_size but taking into account the extra space that
    # some volumes can need to reserve.
    # @see #total_disk_size
    # @see PlannedVolume#needs_reserved?
    #
    # @return [DiskSize] sum of reserved sizes in @volumes
    def reserved_disk_size(min_grain)
      @volumes.reduce(DiskSize.zero) { |sum, vol| sum + vol.reserved_disk_size(:current, min_grain) }
    end

    # Similar to #target_disk_size but taking into account the extra space that
    # some volumes can need to reserve.
    # @see #target_disk_size
    # @see PlannedVolume#needs_reserved?
    #
    # @return [DiskSize]
    def target_reserved_disk_size(min_grain)
      @volumes.reduce(DiskSize.zero) { |sum, vol| sum + vol.reserved_disk_size(target, min_grain) }
    end

    # Total sum of all weights of volumes
    #
    # @return [Float]
    def total_weight
      @volumes.reduce(0.0) { |sum, vol| sum + vol.weight }
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

    # Volumes sorted by a given set of attributes.
    #
    # It sorts by the first attribute in the list. In case of equality, it
    # uses the second element and so on. If all the attributes are equal, the
    # original order is respected.
    #
    # It handles nicely situations with nil values for any of the attributes.
    #
    # @param attrs [Array<Symbol>] names of the attributes to use for sorting
    # @param nils_first [Boolean] whether to put volumes with a value of nil
    #         at the beginning of the result
    # @param descending [Boolean] whether to use descending order
    # @return [Array]
    def sort_by_attr(*attrs, nils_first: false, descending: false)
      @volumes.each_with_index.sort do |one, other|
        compare(one, other, attrs, nils_first, descending)
      end.map(&:first)
    end

    # Returns a copy of the list in which the given space has been distributed
    # among the volumes, distributing the extra space (beyond the target size)
    # according to the weight and max size of each volume.
    #
    # @raise [RuntimeError] if the given space is not enough to reach the target
    #     size for all volumes
    #
    # If the optional argument rounding is used, space will be distributed
    # always in blocks of the specified size.
    #
    # @param space_size [DiskSize]
    # @param rounding [DiskSize, nil] min block size to distribute. Mainly used
    #     to distribute space among LVs honoring the PE size of the LVM
    # @param min_grain [DiskSize, nil] minimal grain of the disk where the space
    #     is located. It only makes sense when distributing space among
    #     partitions. If no value is provided for "rounding", the value of
    #     "min_grain" will be used (to reduce the number of gaps)
    # @return [PlannedVolumesList] list containing volumes with an adjusted
    #     value for PlannedVolume#disk_size
    def distribute_space(space_size, rounding: nil, min_grain: nil)
      raise RuntimeError if space_size < target_disk_size

      rounding ||= min_grain
      rounding ||= DiskSize.new(1)
      new_list = deep_dup
      new_list.each do |vol|
        vol.disk_size = vol.min_valid_disk_size(target)
        rounded = vol.disk_size.ceil(rounding)
        vol.disk_size = rounded unless vol.align == :keep_size && rounded > vol.max
      end

      if min_grain
        used_size = new_list.reserved_disk_size(min_grain)

        # We might be reserving some extra space for some volumes, let's make
        # good use of it where possible
        new_list.with_reserved(min_grain).each do |vol|
          vol.disk_size = [vol.reserved_disk_size(target, min_grain), vol.max_disk_size].min
        end
      else
        used_size = new_list.total_disk_size
      end
      extra_size = space_size - used_size
      new_list.distribute_extra_space!(extra_size, rounding)

      new_list
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

    def to_s
      "#<PlannedVolumesList target=#{@target}, volumes=#{@volumes.map(&:to_s)}>"
    end

  protected

    # @param one [Array] first element: the volume, second: its original index
    # @param other [Array] same structure than previous one
    def compare(one, other, attrs, nils_first, descending)
      one_vol = one.first
      other_vol = other.first
      result = compare_attr(one_vol, other_vol, attrs.first, nils_first, descending)
      if result.zero?
        if attrs.size > 1
          # Try next attribute
          compare(one, other, attrs[1..-1], nils_first, descending)
        else
          # Keep original order by checking the indexes
          one.last <=> other.last
        end
      else
        result
      end
    end

    # @param one [PlannedVolume]
    # @param other [PlannedVolume]
    def compare_attr(one, other, attr, nils_first, descending)
      one_value = one.send(attr)
      other_value = other.send(attr)
      if one_value.nil? || other_value.nil?
        compare_with_nil(one_value, other_value, nils_first)
      else
        compare_values(one_value, other_value, descending)
      end
    end

    # @param one [PlannedVolume]
    # @param other [PlannedVolume]
    def compare_values(one, other, descending)
      if descending
        other <=> one
      else
        one <=> other
      end
    end

    # @param one [PlannedVolume]
    # @param other [PlannedVolume]
    def compare_with_nil(one, other, nils_first)
      if one.nil? && other.nil?
        0
      elsif nils_first
        one.nil? ? -1 : 1
      else
        one.nil? ? 1 : -1
      end
    end

    # Volumes that may grow when distributing the extra space
    #
    # @param volumes [PlannedVolumesList] initial set of all volumes
    # @return [PlannedVolumesList]
    def extra_space_candidates
      candidates = dup
      candidates.delete_if { |vol| vol.disk_size >= vol.max_disk_size }
      candidates
    end

    # Extra space to be assigned to a volume
    #
    # @param volume [PlannedVolume] volume to enlarge
    # @param total_size [DiskSize] free space to be distributed among
    #    involved volumes
    # @param total_weight [Float] sum of the weights of all involved volumes
    # @param assigned_size [DiskSize] space already distributed to other volumes
    # @param rounding [DiskSize] size to round up
    #
    # @return [DiskSize]
    def volume_extra_size(volume, total_size, total_weight, assigned_size, rounding)
      available_size = total_size - assigned_size

      extra_size = total_size * (volume.weight / total_weight)
      extra_size = extra_size.ceil(rounding)
      extra_size = available_size.floor(rounding) if extra_size > available_size

      new_size = extra_size + volume.disk_size
      if new_size > volume.max_disk_size
        # Increase just until reaching the max size
        volume.max_disk_size - volume.disk_size
      else
        extra_size
      end
    end

    def distribute_extra_space!(extra_size, rounding)
      candidates = self
      while distributable?(extra_size, rounding)
        candidates = candidates.extra_space_candidates
        return extra_size if candidates.empty?
        return extra_size if candidates.total_weight.zero?
        log.info("Distributing #{extra_size} extra space among #{candidates.size} volumes")

        assigned_size = DiskSize.zero
        total_weight = candidates.total_weight
        candidates.each do |vol|
          vol_extra = volume_extra_size(vol, extra_size, total_weight, assigned_size, rounding)
          vol.disk_size += vol_extra
          log.info("Distributing #{vol_extra} to #{vol.mount_point}; now #{vol.disk_size}")
          assigned_size += vol_extra
        end
        extra_size -= assigned_size
      end
      log.info("Could not distribute #{extra_size}") unless extra_size.zero?
    end

    def distributable?(size, rounding)
      size >= rounding
    end

    def with_reserved(min_grain)
      @volumes.select { |vol| vol.needs_reserved?(target, min_grain) }
    end
  end
end
