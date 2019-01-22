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
require "y2storage/proposal/space_maker_prospects"

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
        @all_deleted_sids = []
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
        @dist_calculator = PartitionsDistributionCalculator.new(lvm_helper)

        # update storage ids of reused volumes in planned volumes list
        planned_partitions.select(&:reuse?).each do |part|
          p = @original_graph.find_by_name(part.reuse_name)
          part.reuse_sid = p.sid if p
        end

        # Partitions that should not be deleted
        keep = lvm_helper.partitions_in_vg
        # Let's filter out partitions with some value in #reuse_name
        partitions = planned_partitions.dup
        partitions.select(&:reuse?).each do |part|
          log.info "No need to find a fit for this partition, it will reuse #{part.reuse_name}: #{part}"
          keep << part.reuse_name
          partitions.delete(part)
        end

        # map device names to storage ids, as names may change during space making
        keep = keep.map { |x| @original_graph.find_by_name(x) }.compact.map(&:sid)

        calculate_new_graph(partitions, keep, lvm_helper)

        {
          devicegraph:             new_graph,
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
        log.info "BEGIN SpaceMaker#delete_unwanted_partitions"

        result = original_graph.dup
        partition_killer = PartitionKiller.new(result, candidate_disk_names)
        prospects = SpaceMakerProspects::List.new(settings, disk_analyzer)

        disks_for(result).each do |disk|
          prospects.unwanted_partition_prospects(disk).each do |entry|
            sids = partition_killer.delete_by_sid(entry.sid)
            @all_deleted_sids.concat(sids)
          end
        end

        log.info "END SpaceMaker#delete_unwanted_partitions"
        result
      end

    protected

      attr_reader :disk_analyzer, :dist_calculator

      # New devicegraph calculated by {#provide_space}
      # @return [Devicegraph]
      attr_reader :new_graph

      # Auxiliary killer used to calculate {#new_graph}
      # @return [PartitionKiller]
      attr_reader :new_graph_part_killer

      # Sids of the partitions deleted while calculating {#new_graph}. In other
      # words, partitions that where in the original devicegraph passed to
      # {#provide_space} but that are not longer there in {#new_graph}.
      #
      # @return [Array<Integer>]
      attr_reader :new_graph_deleted_sids

      # Partitions from the original devicegraph that are not present in the
      # result of the last call to #provide_space
      #
      # @return [Array<Partition>]
      def deleted_partitions
        original_graph.partitions.select { |p| @all_deleted_sids.include?(p.sid) }
      end

      # @see #provide_space
      #
      # @param partitions [Array<Planned::Partition>] partitions to make space for
      # @param keep [Array<Integer>] sids of partitions that should not be deleted
      # @param lvm_helper [Proposal::LvmHelper] contains information about how
      #     to deal with the existing LVM volume groups
      def calculate_new_graph(partitions, keep, lvm_helper)
        @new_graph = original_graph.duplicate
        @new_graph_part_killer = PartitionKiller.new(@new_graph, candidate_disk_names)
        @new_graph_deleted_sids = []

        # To make sure we are not freeing space in useless places first
        # restrict the operations to disks with particular disk
        # requirements.
        #
        # planned_partitions_by_disk() returns all partitions restricted to
        # a certain disk. Most times partitions are free to be created
        # anywhere but sometimes it is known in advance on which disk they
        # should be created.
        #
        # Doing something similar for #max_start_offset is more difficult and
        # doesn't pay off (#max_start_offset is used just in one case)

        parts_by_disk = planned_partitions_by_disk(partitions)

        # In some cases (for example, if there is only one candidate disk),
        # executing #resize_and_delete with a particular disk name and its
        # restricted set of planned partitions brings no value. It just makes
        # the whole thing harder to debug (bsc#1057436).
        if several_passes?(parts_by_disk)
          # Start by freeing space to the planned partitions that are restricted
          # to a certain disk.
          #
          # The result (if successful) is kept in @distribution.
          #
          parts_by_disk.each do |disk, parts|
            resize_and_delete(parts, keep, lvm_helper, disk_name: disk)
          end
        end

        # Now repeat the process with the full set of planned partitions and all the candidate
        # disks.
        #
        # Note that the result of the run above is not lost as already
        # assigned partitions are taken into account.
        #
        resize_and_delete(partitions, keep, lvm_helper)

        @all_deleted_sids.concat(new_graph_deleted_sids)
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
      # @param keep [Array<Integer>] sids of partitions that should not be deleted
      # @param lvm_helper [Proposal::LvmHelper] contains information about how
      #     to deal with the existing LVM volume groups
      # @param disk_name [String, nil] optional disk name to restrict operations to
      #
      def resize_and_delete(planned_partitions, keep, lvm_helper, disk_name: nil)
        # Note that only the execution with disk_name == nil is the final one.
        # In other words, if disk_name contains something, it means there will
        # be at least a subsequent call to the method.
        log.info "Resize and delete. disk_name: #{disk_name}, planned partitions:"
        planned_partitions.each do |p|
          log.info "  mount: #{p.mount_point}, disk: #{p.disk}, min: #{p.min}, max: #{p.max}"
        end

        # restart evaluation
        @distribution = nil

        prospects = SpaceMakerProspects::List.new(settings, disk_analyzer)
        disks_for(new_graph, disk_name).each do |disk|
          prospects.add_prospects(disk, lvm_helper, keep)
        end

        until success?(planned_partitions)
          break unless execute_next_action(planned_partitions, prospects, disk_name)
        end

        raise Error unless @distribution
      end

      # Performs the next action of {#resize_and_delete}
      #
      # @param planned_partitions [Array<Planned::Partition>] set of partitions to make space for
      # @param prospects [SpaceMakerProspects::List] set of prospect actions
      #   that could be executed
      # @param disk_name [String] optional disk name to restrict operations to
      # @return [Boolean] true if some operation was performed. False if nothing
      #   else could be done to reach the goal.
      def execute_next_action(planned_partitions, prospects, disk_name = nil)
        prospect_action = prospects.next_available_prospect
        if !prospect_action
          log.info "No more prospects for SpaceMaker (disk_name: #{disk_name})"
          return false
        end

        case prospect_action.to_sym
        when :resize_partition
          execute_resize(prospect_action, planned_partitions, disk_name)
        when :delete_partition
          execute_delete(prospect_action, prospects)
        else
          execute_wipe(prospect_action)
        end

        true
      end

      # Performs the action described by a {SpaceMakerProspects::ResizePartition}
      #
      # @param prospect [SpaceMakerProspects::ResizePartition] candidate action
      #   to execute
      # @param planned_partitions [Array<Planned::Partition>] set of partitions to make space for
      # @param disk_name [String, nil] optional disk name to restrict operations to
      def execute_resize(prospect, planned_partitions, disk_name)
        log.info "SpaceMaker#execute_resize - #{prospect}"

        part = new_graph.find_device(prospect.sid)
        target_shrink_size = resizing_size(part, planned_partitions, disk_name)
        shrink_partition(part, target_shrink_size)
        prospect.available = false
      end

      # Performs the action described by a {SpaceMakerProspects::DeletePartition}
      #
      # @param prospect [SpaceMakerProspects::DeletePartition] candidate action
      #   to execute
      # @param prospects [SpaceMakerProspects::List] full set of prospect actions
      def execute_delete(prospect, prospects)
        log.info "SpaceMaker#execute_delete - #{prospect}"

        sids = new_graph_part_killer.delete_by_sid(prospect.sid)
        new_graph_deleted_sids.concat(sids)
        prospects.mark_deleted(sids)
      end

      # Performs the action described by a {SpaceMakerProspects::WipeDisk}
      #
      # @param prospect [SpaceMakerProspects::DeletePartition] candidate action
      #   to execute
      def execute_wipe(prospect)
        log.info "SpaceMaker#execute_wipe - #{prospect}"

        disk = new_graph.find_device(prospect.sid)
        remove_content(disk)
        prospect.available = false
      end

      # Reduces the size of a partition
      #
      # If possible, it reduces the size of the partition by shrink_size.
      # Otherwise, it reduces the size as much as possible.
      #
      # This method does not take alignment into account.
      #
      # @param partition [Partition]
      # @param shrink_size [DiskSize] size of the space to substract ideally
      def shrink_partition(partition, shrink_size)
        log.info "Shrinking #{partition.name}"
        # Explicitly avoid alignment to keep current behavior (to be reconsidered)
        partition.resize(partition.size - shrink_size, align_type: nil)
      end

      # Remove descendants of a disk and also partitions from other disks that
      # are not longer useful afterwards
      #
      # TODO: delete partitions that were part of the removed VG and/or RAID
      #
      # @param disk [Partitionable] disk-like device to cleanup. It must not be
      #   part of a multipath device or a BIOS RAID.
      def remove_content(disk)
        disk.remove_descendants
      end

      # Additional space that needs to be freed while resizing a partition in
      # order to reach the goal
      #
      # @return [DiskSize]
      def resizing_size(partition, planned_partitions, disk_name)
        spaces = free_spaces(new_graph, disk_name)
        dist_calculator.resizing_size(partition, planned_partitions, spaces)
      end

      # List of free spaces in the given devicegraph
      #
      # @param graph [Devicegraph]
      # @param disk [String, nil] optional disk name to restrict result to
      # @return [Array<FreeDiskSpace>]
      def free_spaces(graph, disk = nil)
        disks_for(graph, disk).each_with_object([]) do |d, list|
          list.concat(d.as_not_empty { d.free_spaces })
        end
      end

      # List of candidate disk devices in the given devicegraph
      #
      # @param devicegraph [Devicegraph]
      # @param device_name [String, nil] optional device name to restrict result to
      #
      # @return [Array<Dasd, Disk>]
      def disks_for(devicegraph, device_name = nil)
        filter = device_name ? [device_name] : candidate_disk_names
        devicegraph.blk_devices.select { |d| filter.include?(d.name) }
      end

      # @return [Array<String>]
      def candidate_disk_names
        settings.candidate_devices
      end

      # Whether {#resize_and_delete} should be executed several times,
      # see {#calculate_new_graph} for details.
      #
      # @param parts_by_disk [Hash{String => Array<Planned::Partition>}] see
      #   {#planned_partitions_by_disk}
      # @return [Boolean]
      def several_passes?(parts_by_disk)
        # In this case the result is not much relevant since #resize_and_delete
        # wouldn't be executed for particular disks anyway
        return false if parts_by_disk.empty?

        return true if parts_by_disk.size > 1

        # In theory, the specific disk mentioned in the planned partitions
        # (note that, at this point, we are sure there is only one) should be
        # included in the set of candidate disks. Return false if that's not the
        # case or if there is more than one candidate disk.
        parts_by_disk.keys != candidate_disk_names
      end
    end
  end
end
