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
require "storage"
require "y2storage/planned_volume"
require "y2storage/disk_size"
require "y2storage/free_disk_space"
require "y2storage/proposal/space_distribution"
require "y2storage/refinements"

module Y2Storage
  class Proposal
    # Class to provide free space for creating new partitions - either by
    # reusing existing unpartitioned space, by deleting existing partitions
    # or by resizing an existing Windows partition.
    class SpaceMaker
      using Refinements::Devicegraph
      using Refinements::DevicegraphLists
      include Yast::Logger

      attr_accessor :settings

      # Initialize.
      #
      # @param original_graph [::Storage::Devicegraph] initial devicegraph
      # @param disk_analyzer [DiskAnalyzer] information about original_graph
      # @param settings [ProposalSettings] proposal settings
      def initialize(original_graph, disk_analyzer, settings)
        @original_graph = original_graph
        @disk_analyzer = disk_analyzer
        @settings = settings
      end

      # Performs all the operations needed to free enough space to accomodate
      # a set of volumes
      #
      # @raise Proposal::Error if is not possible to accomodate the volumes
      #
      # @param volumes [PlannedVolumesList] volumes to make space for
      # @return [Hash] a hash with three elements:
      #   devicegraph: [::Storage::Devicegraph] resulting devicegraph
      #   deleted_partitions: [Array<::Storage::Partition>] partitions that
      #     were in the original devicegraph but are not in the resulting one
      #   space_distribution: [SpaceDistribution] proposed distribution of
      #     volumes
      #
      def provide_space(volumes)
        @new_graph = original_graph.duplicate
        @deleted_names = []

        # Partitions that should not be deleted
        keep = []
        # Let's filter out volumes with some value in #reuse
        volumes = volumes.dup
        volumes.select(&:reuse).each do |vol|
          log.info "No need to find a fit for this volume, it will reuse #{vol.reuse}: #{vol}"
          keep << vol.reuse
          volumes.delete(vol)
        end

        # To make sure we are not freeing space in a useless place, let's
        # first restrict the operations to disks with particular requirements
        volumes_by_disk(volumes).each do |disk, vols|
          resize_and_delete!(vols, keep, disk: disk)
        end
        # Doing something similar for #max_start_offset is more difficult and
        # doesn't pay off (#max_start_offset is used just in one case)

        # Now with the full set of volumes and all the candidate disks
        resize_and_delete!(volumes, keep)

        {
          devicegraph:        @new_graph,
          deleted_partitions: deleted_partitions,
          space_distribution: @distribution
        }
      end

    protected

      attr_reader :original_graph, :new_graph, :disk_analyzer

      # Partitions from the original devicegraph that are not present in the
      # result of the last call to #provide_space
      #
      # @return [Array<::Storage::Partition>]
      def deleted_partitions
        original_graph.partitions.with(name: @deleted_names).to_a
      end

      # @return [Hash{String => PlannedVolumesList}]
      def volumes_by_disk(volumes)
        volumes.each_with_object({}) do |volume, hash|
          if volume.disk
            hash[volume.disk] ||= PlannedVolumesList.new([], target: volumes.target)
            hash[volume.disk] << volume
          end
        end
      end

      # Checks whether the goal has already being reached
      #
      # If it returns true, it stores in @distribution the SpaceDistribution
      # that made it possible.
      #
      # @return [Boolean]
      def success?(volumes)
        @distribution ||= SpaceDistribution.best_for(volumes, free_spaces(new_graph).to_a, new_graph)
        !!@distribution
      rescue Error => e
        log.info "Exception while trying to distribute volumes: #{e}"
        @distribution = nil
        false
      end

      # Perform all the needed operations to make space for the volumes
      #
      # @param volumes [PlannedVolumesList] volumes to make space for
      # @param keep [Array<String>] device names of partitions that should not
      #     be deleted
      # @param disk [String] optional disk name to restrict operations to
      def resize_and_delete!(volumes, keep, disk: nil)
        log.info "Resize and delete. disk: #{disk}"

        @distribution = nil

        # Initially, resize only if there are no Linux partitions in the disk
        resize_windows!(volumes, disk, force: false)
        delete_partitions!(volumes, :linux_no_lvm, keep, disk)
        delete_partitions!(volumes, :lvm, keep, disk)
        delete_partitions!(volumes, :other, keep, disk)
        # If everything else failed, try resizing Windows before deleting it
        resize_windows!(volumes, disk, force: true)
        delete_partitions!(volumes, :windows, keep, disk)

        raise NoDiskSpaceError unless success?(volumes)
      end

      # Additional space that needs to be freed in order to reach the goal
      #
      # @return [DiskSize]
      def missing_required_size(volumes, disk)
        SpaceDistribution.missing_disk_size(volumes, free_spaces(new_graph, disk).to_a)
      end

      # List of free spaces in the given devicegraph
      #
      # @param graph [::Storage::Devicegraph]
      # @param disk [String] optional disk name to restrict result to
      # @return [FreeDiskSpacesList]
      def free_spaces(graph, disk = nil)
        disks_for(graph, disk).free_disk_spaces
      end

      # List of candidate disks in the given devicegraph
      #
      # @param devicegraph [::Storage::Devicegraph]
      # @param disk [String] optional disk name to restrict result to
      # @return [DisksList]
      def disks_for(devicegraph, disk = nil)
        filter = disk || candidate_disk_names
        devicegraph.disks.with(name: filter)
      end

      # @return [Array<String>]
      def candidate_disk_names
        settings.candidate_devices
      end

      # Try to resize the existing windows partitions
      #
      # @param volumes [PlannedVolumesList] list of volumes to allocate, used
      #   to know how much space is still missing
      # @param disk [String] optional disk name to restrict operations to
      # @param force [Boolean] whether to resize Windows even if there are
      #   Linux partitions in the same disk
      def resize_windows!(volumes, disk, force: false)
        return if success?(volumes)
        part_names = windows_part_names(disk)
        return if part_names.empty?

        log.info("Resizing Windows partitions (force: #{force}")
        parts_by_disk = partitions_by_disk(part_names)
        remove_linux_disks!(parts_by_disk) unless force

        success = sorted_resizables(parts_by_disk.values.flatten).any? do |res|
          shrink_size = [
            res[:recoverable_size],
            missing_required_size(volumes, disk)
          ].min
          shrink_partition(res[:partition], shrink_size)

          success?(volumes)
        end

        log.info "Didn't manage to free enough space by resizing Windows" unless success
      end

      # @return [Hash{String => ::Storage::Partition}]
      def partitions_by_disk(part_names)
        partitions = new_graph.partitions.with(name: part_names)
        partitions.each_with_object({}) do |partition, hash|
          disk_name = partition.partitionable.name
          hash[disk_name] ||= []
          hash[disk_name] << partition
        end
      end

      def remove_linux_disks!(partitions_by_disk)
        partitions_by_disk.each do |disk, _p|
          if linux_in_disk?(disk)
            log.info "Linux partitions in #{disk}, Windows will not be resized"
            partitions_by_disk.delete(disk)
          end
        end
      end

      def linux_in_disk?(disk_name)
        linux_part_names(disk_name).any?
      end

      # List of partitions that can be resized, including the size of the
      # space that can be reclaimed for each partition.
      #
      # The list is sorted so the partitions with more recoverable space are
      # listed first.
      #
      # @param partitions [Array<::Storage::Partition>] list of partitions
      # @return [Array<Hash>] each element contains
      #     :partition (::Storage::Partition) and :recoverable_size (DiskSize)
      def sorted_resizables(partitions)
        resizables = partitions.map do |part|
          { partition: part, recoverable_size: recoverable_size(part) }
        end

        resizables.delete_if { |res| res[:recoverable_size].zero? }
        resizables.sort_by { |res| res[:recoverable_size] }.reverse
      end

      # Size of the space that can be reclaimed in a partition
      #
      # @param partition [::Storage::Partition]
      # @return [DiskSize]
      def recoverable_size(partition)
        # FIXME: use original_graph because right now #detect_resize_info can
        # only be called in the probed devicegraph. See
        # https://github.com/openSUSE/libstorage-ng/tree/master/storage/Filesystems/FilesystemImpl.cc#L212
        orig_part = find_partition(partition.name, original_graph)
        info = orig_part.filesystem.detect_resize_info
        return DiskSize.zero unless info.resize_ok
        DiskSize.B(partition.size - info.min_size)
      end

      # Reduces the size of a partition
      #
      # @param partition [::Storage::Partition]
      # @param shrink_size [DiskSize] size of the space to substract
      def shrink_partition(partition, shrink_size)
        log.info "Shrinking #{partition.name} by #{shrink_size}"
        partition.size = partition.size - shrink_size.to_i
      end

      # Use force to create space: delete partitions if a given type while
      # there is no suitable space distribution
      #
      # @see #deletion_candidate_partitions for supported types
      #
      # @param volumes [PlannedVolumesList]
      # @param type [Symbol] type of partition to delete
      # @param keep [Array<String>] device names of partitions that should not
      #       be deleted
      # @param disk [String] optional disk name to restrict operations to
      def delete_partitions!(volumes, type, keep, disk)
        return if success?(volumes)

        log.info("Deleting partitions to make space")
        deletion_candidate_partitions(type, disk).each do |part_name|
          if keep.include?(part_name)
            log.info "Skipped deletion of #{part_name}"
            next
          end
          part = find_partition(part_name)
          next unless part

          if type == :lvm
            # Strictly speaking, this could lead to deletion of a partition
            # included in the keep array. In practice it doesn't matter because
            # PVs are never marked to be reused as a PlannedVolume.
            delete_lvm_partitions(part)
          else
            delete_partition(part)
          end

          break if success?(volumes)
        end
      end

      # Deletes the given partition and all other partitions in the candidate
      # disks that are part of the same LVM volume group
      #
      # Rational: when deleting a partition that holds a PV of a given VG, we
      # are effectively killing the whole VG. It makes no sense to leave the
      # other PVs alive. So let's reclaim all the space.
      #
      # @param [partition] A partition that is acting as LVM physical volume
      def delete_lvm_partitions(partition)
        log.info "Deleting #{partition.name}, which is part of an LVM volume group"
        vg_parts = disk_analyzer.used_lvm_partitions.values.detect do |parts|
          parts.map(&:name).include?(partition.name)
        end
        target_parts = vg_parts.map { |p| find_partition(p.name) }.compact
        log.info "These LVM partitions will be deleted: #{target_parts.map(&:name)}"
        target_parts.each do |part|
          delete_partition(part)
        end
      end

      def find_partition(name, graph = new_graph)
        ::Storage::Partition.find_by_name(graph, name)
      rescue
        nil
      end

      # Deletes a given partition from its corresponding partition table.
      # If the partition was the only remaining logical one, it also deletes the
      # now empty extended partition
      def delete_partition(partition)
        log.info("Deleting partition #{partition.name} in device graph")
        if last_logical?(partition)
          log.info("It's the last logical one, so deleting the extended")
          delete_extended(partition.partition_table)
        else
          @deleted_names << partition.name
          partition.partition_table.delete_partition(partition.name)
        end
      end

      # Checks whether the partition is the only logical one in the
      # partition_table
      def last_logical?(partition)
        return false unless partition.type == ::Storage::PartitionType_LOGICAL

        partitions = partition.partition_table.partitions.to_a
        logical_parts = partitions.select { |part| part.type == ::Storage::PartitionType_LOGICAL }
        logical_parts.size == 1
      end

      # Deletes the extended partition and all the logical ones
      def delete_extended(partition_table)
        partitions = partition_table.partitions.to_a
        extended = partitions.detect { |part| part.type == ::Storage::PartitionType_EXTENDED }
        logical_parts = partitions.select { |part| part.type == ::Storage::PartitionType_LOGICAL }

        # This will delete the extended and all the logicals
        @deleted_names << extended.name
        @deleted_names.concat(logical_parts.map(&:name))
        partition_table.delete_partition(extended.name)
      end

      # Partitions of a given type to be deleted. The type can be:
      #
      #  * :windows Partitions with a Windows installation on it
      #  * :linux Partitions that are part of a Linux installation
      #  * :linux_no_lvm Same than above, but excluding partitions that are part
      #       of a LVM volume group
      #  * :lvm Partitions that are part of a LVM volume group
      #  * :other Any other partition
      #
      # Extended partitions are ignored, they will be deleted by
      # #delete_partition if needed
      #
      # @param type [Symbol]
      # @param disk [String] optional disk name to restrict operations to
      # @return [Array<String>] partition names sorted by disk and by position
      #     inside the disk (partitions at the end are presented first)
      def deletion_candidate_partitions(type, disk = nil)
        names = []
        disks_for(original_graph, disk).each do |dsk|
          partitions = original_graph.disks.with(name: dsk.name).partitions.to_a
          partitions.delete_if { |part| part.type == ::Storage::PartitionType_EXTENDED }
          filter_partitions_by_type!(partitions, type, dsk.name)
          partitions = partitions.sort_by { |part| part.region.start }.reverse
          names += partitions.map(&:name)
        end

        log.info "Deletion candidates (#{type}): #{names}"
        names
      end

      def filter_partitions_by_type!(partitions, type, disk)
        case type
        when :windows
          partitions.select! { |part| windows_part_names(disk).include?(part.name) }
        when :linux
          partitions.select! { |part| linux_part_names(disk).include?(part.name) }
        when :linux_no_lvm
          partitions.select! { |part| linux_no_lvm?(part.name, disk) }
        when :lvm
          partitions.select! { |part| lvm_part_names.include?(part.name) }
        when :other
          partitions.select! { |part| other?(part.name, disk) }
        end
      end

      # Checks whether the given partition qualifies as :linux_no_lvm
      # @see #deletion_candidate_partitions
      def linux_no_lvm?(partition_name, disk)
        linux_part_names(disk).include?(partition_name) && !lvm_part_names.include?(partition_name)
      end

      # Checks whether the given partition qualifies as :other
      # @see #deletion_candidate_partitions
      def other?(partition_name, disk)
        !linux_part_names(disk).include?(partition_name) &&
          !windows_part_names(disk).include?(partition_name)
      end

      # Device names of windows partitions detected by disk_analyzer
      #
      # @return [array<string>]
      def windows_part_names(disk = nil)
        parts = if disk
          disk_analyzer.windows_partitions[disk] || []
        else
          disk_analyzer.windows_partitions.values.flatten
        end
        parts.map(&:name)
      end

      # Device names of linux partitions detected by disk_analyzer
      #
      # @return [array<string>]
      def linux_part_names(disk = nil)
        parts = if disk
          disk_analyzer.linux_partitions[disk] || []
        else
          disk_analyzer.linux_partitions.values.flatten
        end
        parts.map(&:name)
      end

      # Device names of used LVM partitions detected by disk_analyzer
      #
      # @return [array<string>]
      def lvm_part_names
        disk_analyzer.used_lvm_partitions.values.flatten.map(&:name)
      end
    end
  end
end
