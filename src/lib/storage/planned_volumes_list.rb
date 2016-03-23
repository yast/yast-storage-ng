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
require "storage/planned_volume"

module Yast
  module Storage
    # Collection of PlannedVolume elements
    #
    # Implements Enumerable and provides some extra methods to query the list of
    # PlannedVolume elements
    class PlannedVolumesList
      include Enumerable
      extend Forwardable

      def initialize(volumes = [])
        @volumes = volumes
      end

      def_delegators :@volumes, :each, :empty?, :length, :size

      def dup
        PlannedVolumesList.new(@volumes.dup)
      end

      # Total sum of all desired sizes of volumes.
      #
      # This tries to avoid an 'unlimited' result:
      # If a the desired size of any volume is 'unlimited',
      # its minimum size is taken instead. This gives a more useful sum in the
      # very common case that any volume has an 'unlimited' desired size.
      #
      # @return [DiskSize] sum of desired sizes in @volumes
      def desired_size
        @volumes.reduce(DiskSize.zero) { |sum, vol| sum + vol.min_valid_size(:desired) }
      end

      # Total sum of all min sizes of volumes.
      #
      # @return [DiskSize] sum of minimum sizes in @volumes
      def min_size
        @volumes.reduce(DiskSize.zero) { |sum, vol| sum + vol.min_valid_size(:min_size) }
      end

      # Total sum of all current sizes of volumes
      #
      # @return [DiskSize] sum of sizes in @volumes
      def total_size
        @volumes.reduce(DiskSize.zero) { |sum, vol| sum + vol.size }
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
    end
  end
end
