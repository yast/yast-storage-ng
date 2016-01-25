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
require "fileutils"
require_relative "./proposal_volume"
require_relative "./disk_size"
require_relative "./free_disk_space"
require "pp"

module Yast
  module Storage
    #
    # Class to create partitions in the free space detected or freed by the
    # SpaceMaker.
    #
    class PartitionCreator
      include Yast::Logger

      attr_accessor :volumes, :devicegraph

      VOLUME_GROUP_SYSTEM = "system"

      # Initialize.
      #
      # @param settings [Storage::Settings] parameters to use
      #
      # @param devicegraph [Storage::Devicegraph] devicegraph to use for any
      #	       changes, typically StorageManager.instance.devicegraph("proposal")
      #
      def initialize(settings:,
		     devicegraph: nil)
	@settings    = settings
	@devicegraph = devicegraph || StorageManager.instance.staging
      end


      # Create all partitions for the specified volumes in the free disk space
      # slots 'free_space' according to the specified strategy (:desired or
      # :min).
      #
      # The partitions are created in the device graph that was specified in
      # the constructor of this object; typically, this will be the "proposal"
      # device graph which is a clone of "proposal_base".
      #
      def create_partitions(volumes, strategy, free_space)

	# FIXME: TO DO
	# FIXME: TO DO
      end

      # Sum up the sizes of all slots in free_space.
      #
      # @return [DiskSize] sum
      #
      def total_free_size(free_space)
	reduce(DiskSize.zero) { |sum, slot| sum + slot.size }
      end

      private

      # Try to create a solution with the current volumes in the current free
      # space. At this point it is already established that there is enough
      # free space (but there might still be other restraints that could make a
      # solution impossible).
      #
      # @param volumes [Array<ProposalVolume>] volumes to create
      # @param free_space [DiskSpace]
      # @param strategy [Symbol] :desired or :min
      #
      def create(volumes, strategy, free_space)
	return create_lvm(volumes, strategy) if @settings.use_lvm
	create_non_lvm(volumes, strategy)
      end

      # Try to create an LVM-based solution.
      #
      # @param volumes [Array<ProposalVolume>] volumes to create
      # @return [bool] 'true' if success, 'false' if failure
      #
      def create_lvm(volumes, strategy)
	lvm_vol, non_lvm_vol = @volumes.partition { |vol| vol.can_live_on_logical_volume }
	create_non_lvm(non_lvm_vol, strategy) unless non_lvm_vol.empty?
	return if lvm_vol.empty?

	volume_group = create_volume_group
	create_physical_volumes(volume_group)

	lvm_vol.each do |vol|
	  create_logical_volume(volume_group, vol)
	end
      end

      # Try to create a solution without LVM.
      #
      # @param volumes  [Array<ProposalVolume] volumes to create
      # @param strategy [Symbol] :desired or :min
      #
      def create_non_lvm(volumes, strategy)
	volumes.each do |vol|
	  # TO DO
	  # TO DO
	  # TO DO
	end
      end
    end
  end
end
