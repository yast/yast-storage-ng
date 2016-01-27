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
    # Class to provide free space for creating new partitions - either by
    # reusing existing unpartitioned space, by deleting existing partitions
    # or by resizing an existing Windows partition.
    #
    class SpaceMaker
      include Yast::Logger

      attr_accessor :volumes, :devicegraph, :free_space, :strategy

      # Free disk space below this size will be disregarded
      TINY_FREE_CHUNK = DiskSize.MiB(30) 

      # Initialize.
      #
      # @param settings [Storage::Settings] parameters to use
      #
      # @param volumes [Array <ProposalVolume>] volumes to find space for.
      #	       The volumes might be changed by this class.
      #
      # @param candidate_disks [Array<string>] device names of disks to install to
      #
      # @param linux_partitions [Array<string>] device names of existing Linux
      #	       partitions
      #
      # @param windows_partitions [Array<string>] device names of Windows
      #	       partitions that can possibly be resized
      #
      # @param devicegraph [Storage::Devicegraph] devicegraph to use for any
      #	       changes, typically StorageManager.instance.devicegraph("proposal")
      #
      def initialize(settings:,
		     volumes:		 [],
		     candidate_disks:	 [],
		     linux_partitions:	 [],
		     windows_partitions: [],
		     devicegraph:	 nil)
	@settings	    = settings
	@volumes	    = volumes
	@candidate_disks    = candidate_disks
	@linux_partitions   = linux_partitions
	@windows_partitions = windows_partitions
	@devicegraph	    = devicegraph || StorageManager.instance.staging
	@free_space	    = []
	@strategy	    = nil # otherwise :desired or :min
	@tried_resize_windows = false
      end

      # Provide disk space according to the specified strategy with the
      # specified method.
      #
      # @param method	[Symbol] one of :find_space, :resize_windows, :make_space
      # @param strategy [Symbol] :desired or :min
      #
      # @return [bool] ok: 'true' if enough space found, 'false' if not
      #
      def provide_space(method, strategy)
	raise ArgumentError, "Bad method name #{method}" unless [:find_space, :resize_windows, :make_space].include?(method)
	raise ArgumentError, "Bad strategy name #{strategy}" unless [:desired, :min_size].include?(strategy)

	required_size = strategy == :desired ? total_desired_sizes : total_vol_sizes(strategy)
	log.info("Providing space with method \"#{method}\" and strategy \"#{strategy}\" - required: #{required_size}")
	@strategy = strategy
	self.send(method, required_size)
	total_free_size >= required_size
      end

      # Try to detect empty (unpartitioned) space.
      #
      def find_space(*unused)
	update_free_space
        @free_space
      end

      # Use force to create space (up to 'required_size'): Delete partitions
      # until there is enough free space.
      #
      # @param required_size [DiskSize]
      #
      def make_space(required_size)
	log.info("Trying to make space for #{required_size}")
	free_size = update_free_space

	prioritized_candidate_partitions.each do |part_name|
	  log.info("Now #{free_size} free - required: #{required_size}")
	  return if free_size >= required_size
	  part = ::Storage::Partition.find(@devicegraph, part_name)
	  next unless part
	  log.info("Deleting partition #{part_name} in device graph")
	  part.partition_table.delete_partition(part_name)
	  free_size = update_free_space
	end
      end

      # Try to resize an existing windows partition - unless there already is
      # a Linux partition which means that
      #
      # @param required_size [DiskSize]
      #
      def resize_windows(required_size)
	return if @tried_resize_windows
	return if @windows_partitions.empty?
	return unless @linux_partitions.empty?

	@tried_resize_windows = true
	log.info("Resizing Windows partition")
	#
	# TO DO: Resize windows partition (not available in libstorage-bgl yet)
	# TO DO: Resize windows partition (not available in libstorage-bgl yet)
	# TO DO: Resize windows partition (not available in libstorage-bgl yet)
	#
      end

      # Delete all partitions on a disk.
      #
      # @param disk [::storage::Disk]
      #
      def delete_all_partitions(disk_name)
	log.info("Deleting all partitions on #{disk_name}")
	ptable_type = nil
	begin
	  disk = ::Storage::Disk.find(@devicegraph, disk_name)
	  ptable_type = disk.partition_table.type # might throw if no partition table
	rescue RuntimeError => ex  # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
	  log.info("CAUGHT exception #{ex}")
	end
	disk.remove_descendants
	ptable_type ||= disk.default_partition_table_type
	disk.create_partition_table(ptable_type)
      end

      # Delete one partition.
      #
      # @param disk_name [string]
      # @param partition_name [string]
      #
      # @return [bool] 'true' if success, 'false' if error
      #
      def delete_partition(disk_name, partition_name)
	log.info("Deleting partition #{partition_name}")
	begin
	  disk = ::Storage::Disk.find(@devicegraph, disk_name)
	  ptable = disk.partition_table # might throw if no partition table
	  ptable.delete_partition(partition_name)
	  true
	rescue RuntimeError => ex  # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
	  log.info("CAUGHT exception #{ex}")
	  false
	end
      end

      # Calculate total sum of all 'size_method' fields of @volumes.
      #
      # @param size_method [Symbol] Name of the size field
      #	       (typically :min_size or :max_size)
      #
      # @return [DiskSize] sum of all 'size_method' in @volumes
      #
      def total_vol_sizes(size_method)
	raise ArgumentError, "Bad method name #{size_method}" unless [:min_size, :max_size].include?(size_method)
	@volumes.reduce(DiskSize.zero) do |sum, vol|
	  sum + vol.send(size_method)
	end
      end

      # Calculate total sum of all desired sizes of @volumes.
      #
      # Unlike total_vol_sizes(:desired_size), this tries to avoid an
      # 'unlimited' result: If a the desired size of any volume is 'unlimited',
      # its minimum size is taken instead. This gives a more useful sum in the
      # very common case that any volume has an 'unlimited' desired size.
      #
      # @return [DiskSize] sum of desired sizes in @volumes
      #
      def total_desired_sizes
	@volumes.reduce(DiskSize.zero) do |sum, vol|
	  sum + (vol.desired_size.unlimited? ? vol.min_size : vol.desired_size)
	end
      end

      # Calculate the total (combined) size of all free slots.
      #
      # @return [DiskSize] total free size
      #
      def total_free_size
	@free_space.reduce(DiskSize.zero) { |sum, slot| sum + slot.size }
      end

      private

      # Update @free_space: Re-read free slots from disk (from libstorage).
      #
      # @return [DiskSize] total free size
      #
      def update_free_space
	@free_space = []
	free_size = DiskSize.zero
	@candidate_disks.each do |disk_name|
	  begin
	    # log.info("Collecting unpartitioned space on #{disk_name}")
	    disk = ::Storage::Disk.find(@devicegraph, disk_name)
	    disk.partition_table.unused_partition_slots.each do |slot|
	      free_slot = FreeDiskSpace.new(disk, slot)
              if free_slot.size >= TINY_FREE_CHUNK
	        @free_space << free_slot
	        free_size += free_slot.size
              end
	    end
	  rescue RuntimeError => ex # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
	    log.info("CAUGHT exception #{ex}")
	    # FIXME: Handle completely empty disks (no partition table) as empty space
	  end
	end
	free_size
      end

      # Return all partition names from all candidate disks.
      #
      # @return [Array<String>] partition_names
      #
      def candidate_partitions
	cand_part = []
	@candidate_disks.each do |disk_name|
	  begin
	    disk = ::Storage::Disk.find(@devicegraph, disk_name)
	    disk.partition_table.partitions.each { |part| cand_part << part.name }
	  rescue RuntimeError => ex # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
	    log.info("CAUGHT exception #{ex}")
	  end
	end
	cand_part
      end

      # Return a prioritized array of candidate partitions (from all candidate
      # disks) in this order:
      #
      # - Linux partitions
      # - Non-Linux and non-Windows partitions
      # - Windows partitions
      #
      # @return [Array<String>] partition_names
      #
      def prioritized_candidate_partitions
	win_part, non_win_part = candidate_partitions.partition do |part|
	  @windows_partitions.include?(part)
	end
	linux_part, non_linux_part = non_win_part.partition do |part|
	  @linux_partitions.include?(part)
	end
	linux_part + non_linux_part + win_part
      end
    end
  end
end
