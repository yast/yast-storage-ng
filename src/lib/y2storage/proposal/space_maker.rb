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
require "y2storage/proposal/space_distribution_calculator"
require "y2storage/proposal/partition_killer"
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
      attr_reader :lvm_helper, :original_graph

      # Initialize.
      #
      # @param original_graph [::Storage::Devicegraph] initial devicegraph
      # @param disk_analyzer [DiskAnalyzer] information about original_graph
      # @param lvm_helper [Proposal::LvmHelper] contains information about the
      #     LVM planned volumes and how to make space for them
      # @param settings [ProposalSettings] proposal settings
      def initialize(original_graph, disk_analyzer, lvm_helper, settings)
        @original_graph = original_graph
        @disk_analyzer = disk_analyzer
        @lvm_helper = lvm_helper
        @settings = settings
      end

      # Performs all the operations needed to free enough space to accomodate
      # a set of planned volumes (that must live out of LVM) and the new
      # physical volumes needed to accomodate the LVM planned volumes.
      #
      # @raise Proposal::Error if is not possible to accomodate the planned
      #   volumes and/or the physical volumes
      #
      # @param no_lvm_volumes [PlannedVolumesList] set of non-LVM volumes to
      #     make space for. The LVM volumes are already handled by #lvm_helper.
      # @return [Hash] a hash with three elements:
      #   devicegraph: [::Storage::Devicegraph] resulting devicegraph
      #   deleted_partitions: [Array<::Storage::Partition>] partitions that
      #     were in the original devicegraph but are not in the resulting one
      #   space_distribution: [SpaceDistribution] proposed distribution of
      #     volumes, including new PVs if necessary
      #
      def provide_space(no_lvm_volumes)
        @new_graph = original_graph.duplicate
        @partition_killer = PartitionKiller.new(@new_graph, disk_analyzer)
        @dist_calculator = SpaceDistributionCalculator.new(lvm_helper)
        @deleted_names = []

        # Partitions that should not be deleted
        keep = lvm_helper.partitions_in_vg
        # Let's filter out volumes with some value in #reuse
        volumes = no_lvm_volumes.dup
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

      attr_reader :new_graph, :disk_analyzer, :partition_killer, :dist_calculator

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
        spaces = free_spaces(new_graph).to_a
        @distribution ||= dist_calculator.best_distribution(volumes, spaces)
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
        delete_partitions!(volumes, :linux, keep, disk)
        delete_partitions!(volumes, :other, keep, disk)
        # If everything else failed, try resizing Windows before deleting it
        resize_windows!(volumes, disk, force: true)
        delete_partitions!(volumes, :windows, keep, disk)

        raise NoDiskSpaceError unless success?(volumes)
      end

      # Additional space that needs to be freed while resizing a partition in
      # order to reach the goal
      #
      # @return [DiskSize]
      def resizing_size(partition, volumes, disk)
        spaces = free_spaces(new_graph, disk).to_a
        dist_calculator.resizing_size(partition, volumes, spaces)
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
            resizing_size(res[:partition], volumes, disk)
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

          # Strictly speaking, this could lead to deletion of a partition
          # included in the keep array. In practice it doesn't matter because
          # PVs and extended partitions are never marked to be reused as a
          # PlannedVolume.
          names = partition_killer.delete(part_name)
          next if names.empty?

          @deleted_names.concat(names)
          break if success?(volumes)
        end
      end

      def find_partition(name, graph = new_graph)
        ::Storage::Partition.find_by_name(graph, name)
      rescue
        nil
      end

      # Partitions of a given type to be deleted. The type can be:
      #
      #  * :windows Partitions with a Windows installation on it
      #  * :linux Partitions that are part of a Linux installation
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
        when :other
          partitions.select! do |part|
            !linux_part_names(disk).include?(part.name) &&
              !windows_part_names(disk).include?(part.name)
          end
        end
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
    end
  end
end
