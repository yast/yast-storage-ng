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

require "fileutils"
require "storage/planned_volumes_collection"
require "storage/disk_size"

module Yast
  module Storage
    class Proposal
      # Class to create partitions in the free space detected or freed by the
      # SpaceMaker.
      class PartitionCreator
        using RefinedDevicegraph
        include Yast::Logger

        attr_accessor :settings

        VOLUME_GROUP_SYSTEM = "system"
        FIRST_LOGICAL_PARTITION_NUMBER = 5 # Number of the first logical partition (/dev/sdx5)

        # Initialize.
        #
        # @param original_graph [::Storage::Devicegraph] initial devicegraph
        # @param settings [Proposal::Settings] proposal settings
        def initialize(original_graph, settings)
          @original_graph = original_graph
          @settings = settings
        end

        # Returns a copy of the original devicegraph in which all the needed
        # partitions have been created.
        #
        # @param volumes [PlannedVolumesCollection] volumes to create
        # @param target_size [Symbol] :desired or :min
        # @return [::Storage::Devicegraph]
        def create_partitions(volumes, target_size)
          self.devicegraph = original_graph.copy

          use_lvm = settings.use_lvm
          use_lvm = false  # Not implemented yet in libstorage-bgl

          if use_lvm
            create_lvm(volumes, target_size)
          else
            create_non_lvm(volumes, target_size)
          end
          devicegraph
        end

      private

        # Working devicegraph
        attr_accessor :devicegraph
        attr_reader :original_graph

        # Sum up the sizes of all slots in the devicegraph
        #
        # @return [DiskSize] sum
        #
        def total_free_size
          devicegraph.available_size
        end

        # List of free slots in the devicegraph
        #
        # @return [Array<FreeDiskSpace>]
        #
        def free_slots
          devicegraph.candidate_spaces
        end

        # Create volumes on LVM.
        #
        # @param volumes [Array<ProposalVolume>] volumes to create
        # @param strategy [Symbol] :desired or :min
        #
        def create_lvm(volumes, strategy)
          lvm_vol, non_lvm_vol = volumes.partition { |vol| vol.can_live_on_logical_volume }
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
        # @param volumes  [Array<ProposalVolume] volumes to create
        # @param strategy [Symbol] :desired or :min_size
        #
        def create_non_lvm(volumes, strategy)
          if free_slots.size == 1
            create_non_lvm_simple(volumes, strategy)
          else
            create_non_lvm_complex(volumes, strategy)
          end
        end

        # Create partitions without LVM in the simple case: There is just one
        # single slot of free disk space, thus we don't need to bother to
        # optimize fitting volumes into the free slots to avoid wasting disk
        # space.
        #
        # @param volumes   [Array<ProposalVolume] volumes to create
        # @param strategy  [Symbol] :desired or :min_size
        #
        def create_non_lvm_simple(volumes, strategy)
          volumes.each { |vol| log.info("vol #{vol.mount_point}\tmin: #{vol.min_size} max: #{vol.max_size} desired: #{vol.desired_size} weight: #{vol.weight}") }

          # Sort out volumes with flexible size vs. fixed size
          flexible_vol, fixed_size_vol = volumes.partition do |vol|
            size = vol.send(strategy)
            size = vol.min_size if size.unlimited?
            size < vol.max_size && vol.weight > 0
          end

          # Add up the sizes of each type
          total_fixed_size    = fixed_size_vol.reduce(DiskSize.zero) { |sum, vol| sum + vol.send(strategy) }
          total_flexible_size = flexible_vol.reduce(DiskSize.zero) do |sum, vol|
            size = vol.send(strategy)
            size = vol.min_size if size.unlimited?
            sum + size
          end
          free_size = total_free_size
          remaining_size = free_size - total_fixed_size - total_flexible_size

          # Set the sizes for all volumes.
          # The remaining_size will be distributed among the unlimited ones later.
          fixed_size_vol.each { |vol| vol.size = vol.send(strategy) }
          flexible_vol.each do |vol|
            vol.size = vol.send(strategy)
            vol.size = vol.min_size if vol.size.unlimited?
          end

          remaining_size = distribute_extra_space(flexible_vol, remaining_size)

          volumes.each do |vol|
            partition_id = vol.mount_point == "swap" ? ::Storage::ID_SWAP : ::Storage::ID_LINUX
            partition = create_partition(vol, partition_id , free_slots.first)
            make_filesystem(partition, vol)
          end
        end

        # Distribute extra disk space among the specified volumes. This updates
        # the size of each volume with the distributed space.
        #
        # @param volumes     [Array<ProposalVolume>]
        # @param extra_size [DiskSpace] disk space to distribute
        #
        # @return [DiskSpace] remaining space that could not be distributed
        #
        def distribute_extra_space(volumes, extra_size)
          log.info("Distributing #{extra_size} extra space among #{volumes.size} volumes")
          while extra_size > DiskSize.zero
            total_weight = volumes.reduce(0.0) do |sum, vol|
              vol.size == vol.max_size ? sum : sum + vol.weight
            end

            return extra_size if total_weight == 0.0 # all volumes at their maximum size

            volumes.each do |vol|
              if vol.size == vol.max_size
                log.info("#{vol.mount_point} is at maximum with #{vol.max_size}")
                next
              end
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
        # @param volumes  [Array<ProposalVolume] volumes to create
        # @param strategy [Symbol] :desired or :min_size
        #
        def create_non_lvm_complex(volumes, strategy)
          raise RuntimeError, "Not implemented yet"
          volumes.each do |vol|
            # TO DO
            # TO DO
            # TO DO
          end
        end

        # Create a partition for the specified volume within the specified slot
        # of free space.
        #
        # @param volume       [ProposalVolume]
        # @param partition_id [::Storage::IdNum] ::Storage::ID_Linux etc.
        # @param free_slot    [FreeDiskSpace]
        #
        def create_partition(vol, partition_id, free_slot)
          log.info("Creating partition for #{vol.mount_point} with #{vol.size}")
          begin
            disk = ::Storage::Disk.find(devicegraph, free_slot.disk_name)
            ptable = disk.partition_table
            if ptable.extended_possible && ptable.num_primary == ptable.max_primary - 1
              if !ptable.has_extended
                # Create an extended partition first
                dev_name = next_free_primary_partition_name(disk.name, ptable)
                ptable.create_partition(dev_name, free_slot.region, ::Storage::EXTENDED)
              end
              dev_name = next_free_logical_partition_name(disk.name, ptable)
              partition_type = ::Storage::LOGICAL
            else
              dev_name = next_free_primary_partition_name(disk.name, ptable)
              partition_type = ::Storage::PRIMARY
            end
            region = new_region_with_size(free_slot, vol.size)
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
          # FIXME: This is broken by design. create_partition needs to return
          # this information, not get it as an input parameter.
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
          # FIXME: This is broken by design. create_partition needs to return
          # this information, not get it as an input parameter.
          part_names = ptable.partitions.to_a.map { |part| part.name }
          FIRST_LOGICAL_PARTITION_NUMBER.upto(ptable.max_logical) do |i|
            dev_name = "#{disk_name}#{i}"
            return dev_name unless part_names.include?(dev_name)
          end
          raise NoMorePartitionSlotError
        end

        # Create a new region from the one in free_slot, but with new size
        # disk_size.
        #
        # @param free_slot [FreeDiskSpace]
        # @param disk_size [DiskSize] new size of the region
        #
        # @return [::Storage::Region] Newly created region
        #
        def new_region_with_size(free_slot, disk_size)
          region = free_slot.slot.region
          blocks = (1024 * disk_size.size_k) / region.block_size
          # region.dup doesn't seem to work (SWIG bindings problem?)
          ::Storage::Region.new(region.start, blocks, region.block_size)
        end

        # Create a filesystem for the specified volume on the specified partition
        # and set its mount point. Do nothing if there is no filesystem
        # configured for 'vol'.
        #
        # @param partition [::Storage::Partition]
        # @param vol       [ProposalVolume]
        #
        # @return [::Storage::Filesystem] filesystem
        #
        def make_filesystem(partition, vol)
          return nil unless vol.filesystem_type
          filesystem = partition.create_filesystem(vol.filesystem_type)
          filesystem.add_mountpoint(vol.mount_point) if vol.mount_point && !vol.mount_point.empty?
          filesystem
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
        # @param vol          [ProposalVolume]
        # @param strategy     [Symbol] :desired or :min_size
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
end
