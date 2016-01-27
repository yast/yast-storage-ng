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
require_relative "./storage_manager"
require_relative "./proposal_settings"
require_relative "./proposal_volume"
require_relative "./disk_size"
require_relative "./space_maker"
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
      FIRST_LOGICAL_PARTITION_NUMBER = 5 # Number of the first logical partition (/dev/sdx5)

      class NoMorePartitionSlotError < RuntimeError
      end

      # Initialize.
      #
      # @param settings [Storage::Settings] parameters to use
      #
      # @param devicegraph [Storage::Devicegraph] devicegraph to use for any
      #	       changes, typically StorageManager.instance.devicegraph("proposal")
      #
      # @param space_maker [SpaceMaker]
      #
      def initialize(settings:,
		     devicegraph: nil,
		     space_maker: nil)
	@settings    = settings
	@devicegraph = devicegraph || StorageManager.instance.staging
	@space_maker = space_maker
      end


      # Create all partitions for the specified volumes in the free disk space
      # slots 'free_space' according to the specified strategy (:desired or
      # :min).
      #
      # The partitions are created in the device graph that was specified in
      # the constructor of this object; typically, this will be the "proposal"
      # device graph which is a clone of "proposal_base".
      #
      # @param volumes [Array<ProposalVolume>] volumes to create
      # @param strategy [Symbol] :desired or :min
      #
      def create_partitions(volumes, strategy)
	# use_lvm = @settings.use_lvm
	use_lvm = false	 # Not implemented yet in libstorage-bgl

	if use_lvm
	  create_lvm(volumes, strategy)
	else
	  create_non_lvm(volumes, strategy)
	end
      end

      # Sum up the sizes of all slots in free_space.
      #
      # @return [DiskSize] sum
      #
      def total_free_size(free_space)
	free_space.reduce(DiskSize.zero) { |sum, slot| sum + slot.size }
      end

      private

      # Create volumes on LVM.
      #
      # @param volumes [Array<ProposalVolume>] volumes to create
      # @param strategy [Symbol] :desired or :min
      #
      def create_lvm(volumes, strategy)
	lvm_vol, non_lvm_vol = @volumes.partition { |vol| vol.can_live_on_logical_volume }
	# Create any partitions first that cannot be created on LVM
	# to avoid LVM consuming all the available free space
	create_non_lvm(non_lvm_vol, strategy)

	if !lvm_vol.empty?
	  # Create LVM partitions (using the rest of the available free space)
	  volume_group = create_volume_group(VOLUME_GROUP_SYSTEM)
	  create_physical_volumes(volume_group)
	  lvm_vol.each { |vol| create_logical_volume(volume_group, vol, strategy) }
	end
      end

      # Create partitions without LVM.
      #
      # @param volumes	[Array<ProposalVolume] volumes to create
      # @param strategy [Symbol] :desired or :min_size
      #
      def create_non_lvm(volumes, strategy)
	free_space = @space_maker.find_space
	if free_space.size == 1
	  create_non_lvm_simple(volumes, strategy, free_space)
	else
	  create_non_lvm_complex(volumes, strategy, free_space)
	end
      end

      # Create partitions without LVM in the simple case: There is just one
      # single slot of free disk space, thus we don't need to bother to
      # optimize fitting volumes into the free slots to avoid wasting disk
      # space.
      #
      # @param volumes	 [Array<ProposalVolume] volumes to create
      # @param strategy	 [Symbol] :desired or :min_size
      # @param free_space [Array<FreeDiskSpace>]
      #
      def create_non_lvm_simple(volumes, strategy, free_space)
	# Sort out volumes with unlimited size vs. limited size
	unlimited_vol, fixed_size_vol = volumes.partition { |vol| vol.send(strategy) == DiskSize.unlimited }

	# Add up the sizes of each type
	total_fixed_size	 = fixed_size_vol.reduce(DiskSize.zero) { |sum, vol| sum + vol.send(strategy) }
	total_unlimited_min_size = unlimited_vol.reduce(DiskSize.zero)	{ |sum, vol| sum += vol.min_size }
	free_size = total_free_size(free_space)
	remaining_size = free_size - total_fixed_size - total_unlimited_min_size

	# Set the sizes for all volumes.
	# The remaining_size will be distributed among the unlimited ones later.
	fixed_size_vol.each { |vol| vol.size = vol.send(strategy) }
	unlimited_vol.each  { |vol| vol.size = vol.min_size }

	remaining_size = distribute_extra_space(unlimited_vol, remaining_size)

	volumes.each do |vol|
	  partition_id = vol.mount_point == "swap" ? ::Storage::ID_SWAP : ::Storage::ID_LINUX
	  partition = create_partition(vol, partition_id , free_space.first)
          partition.create_filesystem(vol.filesystem_type) if partition && vol.filesystem_type
	  free_space = @space_maker.find_space
	end
      end

      # Distribute extra disk space among the specified volumes. This updates
      # the size of each volume with the distributed space.
      #
      # @param volumes	   [Array<ProposalVolume>]
      # @param extra_size [DiskSpace] disk space to distribute
      #
      # @return [DiskSpace] remaining space that could not be distributed
      #
      def distribute_extra_space(volumes, extra_size)
	while extra_size > DiskSize.zero
	  total_weight = volumes.reduce(0.0) do |sum, vol|
	    vol.size == vol.max_size ? sum : sum + vol.weight
	  end

	  return extra_size if total_weight == 0.0 # all volumes at their maximum size

	  volumes.each do |vol|
	    next if vol.size == vol.max_size
	    vol_extra = extra_size * (vol.weight / total_weight)
	    vol.size += vol_extra

	    if vol.size > vol.max_size
	      vol_extra -= vol.size - vol.max_size
	      vol.size = vol.max_size
	    end
	    log.info("Distributing #{vol_extra} to #{vol.mount_point}; now #{vol.size}")
	    extra_size -= vol_extra
	  end
	end
	log.info("Could not distribute #{extra_size}") unless extra_size.zero?
	extra_size
      end

      # Create partitions without LVM in the complex case: There are multiple
      # slots of free disk space, so we need to fit the volumes as good as
      # possible.
      #
      # @param volumes	[Array<ProposalVolume] volumes to create
      # @param strategy [Symbol] :desired or :min_size
      # @param free_space [Array<FreeDiskSpace>] slots of free space
      #
      def create_non_lvm_complex(volumes, strategy, free_space)
	raise RuntimeError, "Not implemented yet"
	volumes.each do |vol|
	  # TO DO
	  # TO DO
	  # TO DO
	  free_space = @space_maker.find_space
	end
      end

      # Create a partition for the specified volume within the specified slot
      # of free space.
      #
      # @param volume	    [ProposalVolume]
      # @param partition_id [::Storage::IdNum] ::Storage::ID_Linux etc.
      # @param free_slot    [FreeDiskSpace]
      #
      def create_partition(vol, partition_id, free_slot)
	log.info("Creating partition for #{vol.mount_point} with #{vol.size}")
	begin
	  disk = ::Storage::Disk.find(@devicegraph, free_slot.disk_name)
	  ptable = disk.partition_table
	  if ptable.extended_possible && ptable.num_primary == ptable.max_primary - 1
	    if !ptable.has_extended
	      # Create an extended partition first
	      dev_name = next_free_primary_partition_name(disk_name, partition_table)
	      ptable.create_partition(dev_name, free_slot.region, ::Storage::EXTENDED)
	    end
	    dev_name = next_free_logical_partition_name(disk.name, ptable)
	    partition_type = ::Storage::LOGICAL
	  else
	    dev_name = next_free_primary_partition_name(disk.name, ptable)
	    partition_type = ::Storage::PRIMARY
	  end
	  region = new_region_with_size(free_slot, vol.size)
	  log.info("region block size: #{region.block_size}")
	  partition = ptable.create_partition(dev_name, region, partition_type)
	  partition.id = partition_id
	  partition
        rescue RuntimeError => ex # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
	  log.info("CAUGHT exception #{ex}")
	  nil
	end
      end

      # Return the next device name for a primary partition that is not already
      # in use.
      #
      # @return [String] device_name ("/dev/sdx1", "/dev/sdx2", ...)
      #
      def next_free_primary_partition_name(disk_name, ptable)
	part_names = ptable.partitions.to_a.map { |part| part.name }
	1.upto(ptable.max_primary) do |i|
	  dev_name = "#{disk_name}#{i}"
	  return dev_name unless part_names.include?(dev_name)
	end
	raise NoMorePartitionSlotError
      end

      # Return the next device name for a logical partition that is not already
      # in use. The first one is always /dev/sdx5.
      #
      # @return [String] device_name ("/dev/sdx5", "/dev/sdx6", ...)
      #
      def next_free_logical_partition_name(disk_name, ptable)
	part_names = ptable.partitions.map { |part| part.name }
	FIRST_LOGICAL_PARTITION_NUMBER.upto(ptable.max_logical) do |i|
	  dev_name = "#{disk_name}#{i}"
	  return dev_name unless part_names.include?(dev_name)
	end
	raise NoMorePartitionSlotError
      end

      # Create a new region from the one in free_slot, but with new size disk_size.
      #
      # @param free_slot [FreeDiskSpace]
      # @param disk_size [DiskSize] new size of the region
      #
      # @return [::Storage::Region] Newly created region
      #
      def new_region_with_size(free_slot, disk_size)
        region = free_slot.slot.region
	log.info("blocks size: #{region.block_size}")
	blocks = (1024 * disk_size.size_k) / region.block_size
	log.info("blocks: #{blocks}")
        # region.dup doesn't seem to work (SWIG bindings problem?)
	::Storage::Region.new(region.start, blocks, region.block_size)
      end

      # Create an LVM volume group.
      #
      # @param volum_group_name [String]
      #
      # @return [::Storage::VolumeGroup] volume_group
      #
      def create_volume_group(volume_group_name)
	volume_group = nil
	log.info("Creating LVM volume group #{volume_group_name}")
	raise RuntimeError, "Not implemented yet"
	# TO DO
	# TO DO
	# TO DO
	return volume_group
      end

      # Create LVM physical volumes for all the rest of free_space and add them
      # to the specified volume group.
      #
      # @param volume_group [::Storage::VolumeGroup]
      #
      def create_physical_volumes(volume_group)
	log.info("Creating LVM physical volumes")
      end

      # Create an LVM logical volume in the specified volume group for vol.
      #
      # @param volume_group [::Storage::VolumeGroup]
      # @param vol	    [ProposalVolume]
      # @param strategy	    [Symbol] :desired or :min_size
      #
      def create_logical_volume(volume_group, vol, strategy)
	log.info("Creating LVM logical volume #{vol.logical_volume_name} with strategy \"#{strategy}\"")
	# TO DO
	# TO DO
	# TO DO
      end
    end
  end
end
