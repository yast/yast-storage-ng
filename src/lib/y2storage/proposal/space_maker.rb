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
require "y2storage/planned"
require "y2storage/partition"
require "y2storage/disk_size"
require "y2storage/free_disk_space"
require "y2storage/proposal/partitions_distribution_calculator"
require "y2storage/proposal/partition_killer"

module Y2Storage
  module Proposal
    # Class to provide free space for creating new partitions - either by
    # reusing existing unpartitioned space, by deleting existing partitions
    # or by resizing an existing Windows partition.
    class SpaceMaker
      include Yast::Logger

      attr_accessor :settings
      attr_reader :original_graph

      # Initialize.
      #
      # @param disk_analyzer [DiskAnalyzer] information about existing partitions
      # @param settings [ProposalSettings] proposal settings
      def initialize(disk_analyzer, settings)
        @disk_analyzer = disk_analyzer
        @settings = settings
        @deleted_names = []
      end

      # Performs all the operations needed to free enough space to accomodate
      # a set of planned partitions and the new physical volumes needed to
      # accomodate the planned LVM logical volumes.
      #
      # @raise [Error] if is not possible to accomodate the planned
      #   partitions and/or the physical volumes
      #
      # @param original_graph [Devicegraph] initial devicegraph
      # @param planned_partitions [Array<Planned::Partition>] set of partitions to make space for
      # @param lvm_helper [Proposal::LvmHelper] contains information about the
      #     planned LVM logical volumes and how to make space for them
      # @return [Hash] a hash with three elements:
      #   devicegraph: [Devicegraph] resulting devicegraph
      #   deleted_partitions: [Array<Partition>] partitions that
      #     were in the original devicegraph but are not in the resulting one
      #   partitions_distribution: [Planned::PartitionsDistribution] proposed
      #     distribution of partitions, including new PVs if necessary
      #
      def provide_space(original_graph, planned_partitions, lvm_helper)
        @original_graph = original_graph
        @new_graph = original_graph.duplicate
        @dist_calculator = PartitionsDistributionCalculator.new(lvm_helper)

        # Partitions that should not be deleted
        keep = lvm_helper.partitions_in_vg
        # Let's filter out partitions with some value in #reuse
        partitions = planned_partitions.dup
        partitions.select(&:reuse).each do |part|
          log.info "No need to find a fit for this partition, it will reuse #{part.reuse}: #{part}"
          keep << part.reuse
          partitions.delete(part)
        end

        # To make sure we are not freeing space in useless places first
        # restrict the operations to disks with particular disk
        # requirements.
        #
        # planned_partitions_by_disk() returns all partitions restricted to
        # a certain disk. Most times partitions are free to be created
        # anywhere but sometimes it is known in advance on which disk they
        # should be created.
        #
        # Start by assigning space to them.
        #
        # The result (if successful) is kept in @distribution.
        #
        planned_partitions_by_disk(partitions).each do |disk, parts|
          resize_and_delete!(parts, keep, lvm_helper, disk: disk)
        end

        # Doing something similar for #max_start_offset is more difficult and
        # doesn't pay off (#max_start_offset is used just in one case)

        # Now repeat the process with the full set of planned partitions and all the candidate
        # disks.
        #
        # Note that the result of the run above is not lost as already
        # assigned partitions are taken into account.
        #
        resize_and_delete!(partitions, keep, lvm_helper)

        {
          devicegraph:             @new_graph,
          deleted_partitions:      deleted_partitions,
          partitions_distribution: @distribution
        }
      end

      # Deletes all partitions explicitly marked for removal in the proposal
      # settings, i.e. all the partitions belonging to one of the types with
      # delete_mode set to :all.
      #
      # @see #windows_delete_mode
      # @see #linux_delete_mode
      # @see #other_delete_mode
      #
      # @param original_graph [Devicegraph] initial devicegraph
      # @return [Devicegraph] copy of #original_graph without the unwanted
      #   partitions
      def delete_unwanted_partitions(original_graph)
        result = original_graph.dup

        [:windows, :linux, :other].each do |type|
          next unless settings.delete_forced?(type)

          log.info("Forcely deleting #{type} partitions")
          delete_candidates!(result, type)
        end

        result
      end

    protected

      attr_reader :new_graph, :disk_analyzer, :dist_calculator

      # Partitions from the original devicegraph that are not present in the
      # result of the last call to #provide_space
      #
      # @return [Array<Partition>]
      def deleted_partitions
        original_graph.partitions.select { |p| @deleted_names.include?(p.name) }
      end

      # @return [Hash{String => Array<Planned::Partition>}]
      def planned_partitions_by_disk(planned_partitions)
        planned_partitions.each_with_object({}) do |partition, hash|
          if partition.disk
            hash[partition.disk] ||= []
            hash[partition.disk] << partition
          end
        end
      end

      # Checks whether the goal has already being reached
      #
      # If it returns true, it stores in @distribution the PartitionsDistribution
      # that made it possible.
      #
      # @return [Boolean]
      def success?(planned_partitions)
        # Once a distribution has been found we don't have to look for another one.
        if !@distribution
          spaces = free_spaces(new_graph)
          @distribution = dist_calculator.best_distribution(planned_partitions, spaces)
        end
        !!@distribution
      rescue Error => e
        log.info "Exception while trying to distribute partitions: #{e}"
        @distribution = nil
        false
      end

      # Perform all the needed operations to make space for the partitions
      #
      # @param planned_partitions [Array<Planned::Partition>] partitions
      #     to make space for
      # @param keep [Array<String>] device names of partitions that should not
      #     be deleted
      # @param lvm_helper [Proposal::LvmHelper] contains information about how
      #     to deal with the existing LVM volume groups
      # @param disk [String] optional disk name to restrict operations to
      #
      # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
      #
      def resize_and_delete!(planned_partitions, keep, lvm_helper, disk: nil)
        log.info "Resize and delete. disk: #{disk}, planned partitions:"
        planned_partitions.each do |p|
          log.info "  mount: #{p.mount_point}, disk: #{p.disk}, min: #{p.min}, max: #{p.max}"
        end

        # restart evaluation
        @distribution = nil

        # maybe it works already...
        return if success?(planned_partitions)

        # Try various methods to free space. Stop when a valid partition
        # layout has been found.

        # step 1
        # resize Windows partitions only if there are no Linux partitions on the disk
        log.info "Step 1"
        resize_windows!(planned_partitions, disk, force: false)
        return if @distribution

        # step 2
        # delete Linux partitions
        log.info "Step 2"
        delete_partitions!(planned_partitions, :linux, keep, disk)
        return if @distribution

        # step 3
        # delete other (non-Windows) partitions
        log.info "Step 3"
        delete_partitions!(planned_partitions, :other, keep, disk)
        return if @distribution

        # step 4
        # resize Windows partitions
        log.info "Step 4"
        resize_windows!(planned_partitions, disk, force: true)
        return if @distribution

        # step 5
        # delete Windows partitions
        log.info "Step 5"
        delete_partitions!(planned_partitions, :windows, keep, disk)
        return if @distribution

        # step 6
        # if deleting partitions was not enough, maybe there is no partition
        # table and we have to wipe the disk
        log.info "Step 6"
        delete_disk_content(planned_partitions, lvm_helper, disk)

        raise Error unless @distribution
      end
      # rubocop:enable all

      # Additional space that needs to be freed while resizing a partition in
      # order to reach the goal
      #
      # @return [DiskSize]
      def resizing_size(partition, planned_partitions, disk)
        spaces = free_spaces(new_graph, disk)
        dist_calculator.resizing_size(partition, planned_partitions, spaces)
      end

      # List of free spaces in the given devicegraph
      #
      # @param graph [Devicegraph]
      # @param disk [String] optional disk name to restrict result to
      # @return [Array<FreeDiskSpace>]
      def free_spaces(graph, disk = nil)
        disks_for(graph, disk).each_with_object([]) do |d, list|
          list.concat(d.as_not_empty { d.free_spaces })
        end
      end

      # List of candidate disk devices in the given devicegraph
      #
      # @param devicegraph [Devicegraph]
      # @param device_name [String] optional device name to restrict result to
      #
      # @return [Array<Dasd, Disk>]
      def disks_for(devicegraph, device_name = nil)
        filter = device_name || candidate_disk_names
        devicegraph.disk_devices.select { |d| filter.include?(d.name) }
      end

      # @return [Array<String>]
      def candidate_disk_names
        settings.candidate_devices
      end

      # Try to resize the existing windows partitions
      #
      # @param planned_partitions [Array<Planned::Partition>] list of
      #   partitions to allocate, used to know how much space is still missing
      # @param disk [String] optional disk name to restrict operations to
      # @param force [Boolean] whether to resize Windows even if there are
      #   Linux partitions in the same disk
      def resize_windows!(planned_partitions, disk, force: false)
        return unless settings.resize_windows
        part_names = windows_part_names(disk)
        return if part_names.empty?

        log.info("Resizing Windows partitions (force: #{force})")
        parts_by_disk = partitions_by_disk(part_names)
        remove_linux_disks!(parts_by_disk) unless force

        success = sorted_resizables(parts_by_disk.values.flatten).any? do |res|
          shrink_size = [
            res[:recoverable_size],
            resizing_size(res[:partition], planned_partitions, disk)
          ].min
          shrink_partition(res[:partition], shrink_size)

          success?(planned_partitions)
        end

        log.info "Didn't manage to free enough space by resizing Windows" unless success
      end

      # @return [Hash{String => Partition}]
      def partitions_by_disk(part_names)
        partitions = new_graph.partitions.select { |p| part_names.include?(p.name) }
        partitions.each_with_object({}) do |partition, hash|
          disk_name = partition.partitionable.name
          hash[disk_name] ||= []
          hash[disk_name] << partition
        end
      end

      def remove_linux_disks!(parts_by_disk)
        parts_by_disk.each do |disk, _p|
          if linux_in_disk?(disk)
            log.info "Linux partitions in #{disk}, Windows will not be resized"
            parts_by_disk.delete(disk)
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
      # @param partitions [Array<Partition>] list of partitions
      # @return [Array<Hash>] each element contains
      #     :partition (Partition) and :recoverable_size (DiskSize)
      def sorted_resizables(partitions)
        resizables = partitions.map do |part|
          { partition: part, recoverable_size: recoverable_size(part) }
        end

        resizables.delete_if { |res| res[:recoverable_size].zero? }
        resizables.sort_by { |res| res[:recoverable_size] }.reverse
      end

      # Size of the space that can be reclaimed in a partition
      #
      # @param partition [Partition]
      # @return [DiskSize]
      def recoverable_size(partition)
        info = partition.filesystem.detect_resize_info
        return DiskSize.zero unless info.resize_ok?
        partition.size - info.min_size
      end

      # Reduces the size of a partition
      #
      # @param partition [Partition]
      # @param shrink_size [DiskSize] size of the space to substract
      def shrink_partition(partition, shrink_size)
        log.info "Shrinking #{partition.name} (#{partition.size}) by #{shrink_size}"
        partition.size = partition.size - shrink_size
      end

      # Use force to create space: delete partitions if a given type while
      # there is no suitable space distribution
      #
      # @see #deletion_candidate_partitions for supported types
      #
      # @param planned_partitions [Array<Planned::Partition>]
      # @param type [Symbol] type of partition to delete
      # @param keep [Array<String>] device names of partitions that should not
      #       be deleted
      # @param disk [String] optional disk name to restrict operations to
      def delete_partitions!(planned_partitions, type, keep, disk)
        return if settings.delete_forbidden?(type)

        log.info("Deleting partitions to make space")
        delete_candidates!(new_graph, type, keep, disk) { success?(planned_partitions) }
      end

      # @see #delete_partitions! and #delete_unwanted_partitions
      def delete_candidates!(devicegraph, type, keep = [], disk = nil)
        partition_killer = PartitionKiller.new(devicegraph, candidate_disk_names)

        deletion_candidate_partitions(devicegraph, type, disk).each do |part_name|
          if keep.include?(part_name)
            log.info "Skipped deletion of #{part_name}"
            next
          end

          # Strictly speaking, this could lead to deletion of a partition
          # included in the keep array. In practice it doesn't matter because
          # PVs and extended partitions are never marked to be reused as a
          # planned partition.
          names = partition_killer.delete(part_name)
          next if names.empty?

          @deleted_names.concat(names)
          # Stop deleting if the passed condition is met
          break if block_given? && yield
        end
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
      # @param devicegraph [Devicegraph]
      # @param type [Symbol]
      # @param disk [String] optional disk name to restrict operations to
      # @return [Array<String>] partition names sorted by disk and by position
      #     inside the disk (partitions at the end are presented first)
      def deletion_candidate_partitions(devicegraph, type, disk = nil)
        names = []
        disks_for(devicegraph, disk).each do |dsk|
          partitions = devicegraph.partitions.select { |p| p.partitionable.name == dsk.name }
          partitions.delete_if { |part| part.type.is?(:extended) }
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

      # Wipe the content of disk-like devices not containining a partition table,
      # like disks directly formatted or used as members of an LVM or software RAID.
      #
      # @param planned_partitions [Array<Planned::Partition>] list of
      #   partitions to allocate, used to know how much space is still missing
      # @param lvm_helper [Proposal::LvmHelper] contains information about how
      #     to deal with the existing LVM volume groups
      # @param disk [String] optional disk name to restrict operations to
      def delete_disk_content(planned_partitions, lvm_helper, disk)
        log.info "BEGIN delete_disk_content with disk #{disk}"

        disks_for(new_graph, disk).each do |dsk|
          log.info "Checking if the disk #{dsk.name} has a partition table"

          next unless dsk.has_children? && dsk.partition_table.nil?

          log.info "Found something that is not a partition table"
          remove_content(dsk, lvm_helper)

          break if success?(planned_partitions)
        end

        log.info "END delete_disk_content"
      end

      # Remove descendants of a disk and also partitions from other disks that
      # are not longer useful afterwards
      #
      # TODO: delete partitions that were part of the removed VG and/or RAID
      #
      # @param disk [Partitionable] disk-like device to cleanup. It must not be
      #   part of a multipath device or a BIOS RAID.
      # @param lvm_helper [Proposal::LvmHelper] contains information about how
      #     to deal with the existing LVM volume groups
      def remove_content(disk, lvm_helper)
        if disk.descendants.any? { |dev| lvm_helper.vg_to_reuse?(dev) }
          log.info "Not cleaning up #{disk.name} because its VG must be reused"
          return
        end
        disk.remove_descendants
      end

      # Device names of windows partitions detected by disk_analyzer
      #
      # @return [array<string>]
      def windows_part_names(disk = nil)
        parts = if disk
          disk_analyzer.windows_partitions(disk)
        else
          disk_analyzer.windows_partitions
        end
        parts.map(&:name)
      end

      # Device names of linux partitions detected by disk_analyzer
      #
      # @return [array<string>]
      def linux_part_names(disk = nil)
        parts = if disk
          disk_analyzer.linux_partitions(disk)
        else
          disk_analyzer.linux_partitions
        end
        parts.map(&:name)
      end
    end
  end
end
