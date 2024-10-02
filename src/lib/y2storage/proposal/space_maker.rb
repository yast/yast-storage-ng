# Copyright (c) [2015-2024] SUSE LLC
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
require "y2storage/partitionable"
require "y2storage/disk_size"
require "y2storage/free_disk_space"
require "y2storage/proposal/partitions_distribution_calculator"
require "y2storage/proposal/space_maker_actions"

module Y2Storage
  module Proposal
    # Class to provide free space for creating new partitions - either by
    # reusing existing unpartitioned space, by deleting existing partitions
    # or by resizing an existing Windows partition.
    class SpaceMaker
      include Yast::Logger

      attr_accessor :settings
      attr_reader :original_graph

      # Sids of devices that should not be affected by SpaceMaker changes
      #
      # The devices should not be deleted or resized either directly (in the case of partitions)
      # or indirectly. For example, if the sid corresponds to an LVM LV, none of the partitions
      # that act as PV of the same volume group should be deleted or resized.
      #
      # @return [Array<Integer>]
      attr_accessor :protected_sids

      # Initialize.
      #
      # @param disk_analyzer [DiskAnalyzer] information about existing partitions
      # @param settings [ProposalSpaceSettings] space settings
      def initialize(disk_analyzer, settings)
        @disk_analyzer = disk_analyzer
        @settings = settings
        @all_deleted_sids = []
        @protected_sids = []
      end

      # Performs all the operations needed to free enough space to accomodate
      # a set of planned partitions and the new physical volumes needed to
      # accomodate the planned LVM logical volumes.
      #
      # @raise [Error] if is not possible to accomodate the planned
      #   partitions and/or the physical volumes
      #
      # @param original_graph [Devicegraph] initial devicegraph
      # @param default_disks [Array<Strings>] disks that will be used to allocate those partitions
      #   with no concrete disks and the physical volumes of the LVM volume group
      # @param planned_partitions [Array<Planned::Partition>] set of partitions to make space for
      # @param planned_vg [Planned::LvmVg, nil] planned system LVM volume group. Nil if there is no
      #   need to create space for the system VG
      # @return [Hash] a hash with three elements:
      #   devicegraph: [Devicegraph] resulting devicegraph
      #   deleted_partitions: [Array<Partition>] partitions that
      #     were in the original devicegraph but are not in the resulting one
      #   partitions_distribution: [Planned::PartitionsDistribution] proposed
      #     distribution of partitions, including new PVs if necessary
      #
      def provide_space(original_graph, default_disks, planned_partitions, planned_vg = nil)
        @original_graph = original_graph
        @dist_calculator = PartitionsDistributionCalculator.new(planned_vg)

        calculate_new_graph(default_disks, planned_partitions, planned_vg)

        {
          devicegraph:             new_graph,
          deleted_partitions:      deleted_partitions,
          partitions_distribution: @distribution
        }
      end

      # Executes all the mandatory actions to make space (see #{SpaceMakerActions::List})
      #
      # @param original_graph [Devicegraph] initial devicegraph
      # @param disks [Array<Strings>] set of disk names to operate on
      # @return [Devicegraph] copy of #original_graph after performing the actions
      def prepare_devicegraph(original_graph, disks)
        log.info "BEGIN SpaceMaker#prepare_devicegraph"

        result = original_graph.dup
        actions = SpaceMakerActions::List.new(settings, disk_analyzer)
        @candidate_disk_names = disks

        disks.each do |disk_name|
          disk = result.find_by_name(disk_name)
          next unless disk

          actions.add_mandatory_actions(disk)
        end
        skip = all_protected_sids(result)

        while (action = actions.next)
          sids = execute_action(action, result, skip)
          actions.done(sids)
          @all_deleted_sids.concat(sids)
        end

        log.info "END SpaceMaker#prepare_devicegraph"
        result
      end

      protected

      attr_reader :disk_analyzer, :dist_calculator

      # Disks that are not candidate devices but still must be considered because
      # there are planned partitions explicitly targeted to those disks
      # @return [Array<String>]
      attr_reader :extra_disk_names

      # New devicegraph calculated by {#provide_space}
      # @return [Devicegraph]
      attr_reader :new_graph

      # Sids of the partitions deleted while calculating {#new_graph}. In other
      # words, partitions that where in the original devicegraph passed to
      # {#provide_space} but that are not longer there in {#new_graph}.
      #
      # @return [Array<Integer>]
      attr_reader :new_graph_deleted_sids

      # @return [Array<String>]
      attr_reader :candidate_disk_names

      # Partitions from the original devicegraph that are not present in the
      # result of the last call to #provide_space
      #
      # @return [Array<Partition>]
      def deleted_partitions
        original_graph.partitions.select { |p| @all_deleted_sids.include?(p.sid) }
      end

      # @see #provide_space
      #
      # @param default_disk_names [Array<Strings>] see {#provide_space}
      # @param partitions [Array<Planned::Partition>] partitions to make space for
      # @param volume_group [Planned::LvmVg, nil] planned system LVM volume group
      def calculate_new_graph(default_disk_names, partitions, volume_group)
        @new_graph = original_graph.duplicate
        @new_graph_deleted_sids = []
        @candidate_disk_names = default_disk_names
        @extra_disk_names = partitions.map(&:disk).compact.uniq - candidate_disk_names

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
            resize_and_delete(parts, volume_group, disk_name: disk)
          rescue Error
            # If LVM was involved, maybe there is still hope if we don't abort on this error.
            raise unless dist_calculator.lvm?

            # dist_calculator tried to allocate the specific partitions for this disk but also
            # all new physical volumes for the LVM. If the physical volumes were the culprit, we
            # should keep trying to delete/resize stuff in other disks.
            raise unless find_distribution(parts, ignore_lvm: true)
          end
        end

        # Now repeat the process with the full set of planned partitions and all the candidate
        # disks.
        #
        # Note that the result of the run above is not lost as already
        # assigned partitions are taken into account.
        #
        resize_and_delete(partitions, volume_group)

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
        @distribution ||= find_distribution(planned_partitions)
        !!@distribution
      rescue Error => e
        log.info "Exception while trying to distribute partitions: #{e}"
        @distribution = nil
        false
      end

      # Finds the best distribution to allocate the given set of planned partitions
      #
      # In case of an LVM-based proposal, the distribution will also include any needed physical
      # volume for the system LVM. The argument ignore_lvm can be used to disable that requirement.
      #
      # @param planned_partitions [Array<Planned::Partition>]
      # @param ignore_lvm [Boolean]
      # @return [Planned::PartitionsDistribution, nil] nil if no valid distribution was found
      def find_distribution(planned_partitions, ignore_lvm: false)
        calculator = ignore_lvm ? non_lvm_dist_calculator : dist_calculator
        calculator.best_distribution(planned_partitions, free_spaces, extra_free_spaces)
      end

      # Perform all the needed operations to make space for the partitions
      #
      # @param planned_partitions [Array<Planned::Partition>] partitions
      #     to make space for
      # @param volume_group [Planned::LvmVg, nil] planned system LVM volume group, if any
      # @param disk_name [String, nil] optional disk name to restrict operations to
      #
      def resize_and_delete(planned_partitions, volume_group, disk_name: nil)
        # Note that only the execution with disk_name == nil is the final one.
        # In other words, if disk_name contains something, it means there will
        # be at least a subsequent call to the method.
        log.info "Resize and delete. disk_name: #{disk_name}, planned partitions:"
        planned_partitions.each do |p|
          log.info "  mount: #{p.mount_point}, disk: #{p.disk}, min: #{p.min}, max: #{p.max}"
        end

        # restart evaluation
        @distribution = nil
        force_ptables(planned_partitions)

        actions = SpaceMakerActions::List.new(settings, disk_analyzer)
        disks_for(new_graph, disk_name).each do |disk|
          actions.add_optional_actions(disk, volume_group)
        end
        skip = all_protected_sids(new_graph)

        until success?(planned_partitions)
          break unless execute_next_action(actions, planned_partitions, skip, disk_name)
        end

        raise Error unless @distribution
      end

      def force_ptables(planned_partitions)
        forced = planned_partitions.select { |part| part.disk && part.ptable_type }
        forced.each do |part|
          disk = new_graph.find_by_name(part.disk)
          disk.forced_ptable_type = part.ptable_type
        end
      end

      # Identifiers of all the devices that should be kept as-is, either because their are
      # part of #protected_sids or because they would affect them indirectly
      #
      # @param devicegraph [Devicegraph] graph used to calculate the relationship between sids
      # @return [Array<Integer>]
      def all_protected_sids(devicegraph)
        devices = protected_sids.map { |s| devicegraph.find_device(s) }.compact
        all_devices = devices + devices.flat_map(&:ancestors)
        all_devices.map(&:sid)
      end

      # Performs the next action of {#resize_and_delete}
      #
      # @param actions [SpaceMakerActions::List] set of actions that could be executed
      # @param planned_partitions [Array<Planned::Partition>] set of partitions to make space for
      # @param skip [Array<Integer>] sids of devices that should not be modified
      # @param disk_name [String] optional disk name to restrict operations to
      # @return [Boolean] true if some operation was performed. False if nothing
      #   else could be done to reach the goal.
      def execute_next_action(actions, planned_partitions, skip, disk_name = nil)
        action = actions.next
        if !action
          log.info "No more actions for SpaceMaker (disk_name: #{disk_name})"
          return false
        end

        sids = execute_action(action, new_graph, skip, planned_partitions, disk_name)
        actions.done(sids)
        new_graph_deleted_sids.concat(sids)
        true
      end

      # Executes the given SpaceMaker action
      #
      # @param action [SpaceMakerActions::Base] action to execute
      # @param graph [Devicegraph] devicegraph in which the action will be executed
      # @param skip [Array<Integer>] sids of devices that should not be modified
      # @param planned_partitions [Array<Planned::Partition>, nil] set of partitions to make space
      #   for, if known. Nil for mandatory operations executed during {#prepare_devicegraph}.
      # @param disk_name [String, nil] optional disk name to restrict operations to
      # @return [Array<Integer>] sids of the devices that has been deleted as a consequence
      #   of the action
      def execute_action(action, graph, skip, planned_partitions = nil, disk_name = nil)
        if skip.include?(action.sid)
          log.info "Skipping action on device #{action.sid} (#{action.class})"
          return []
        end

        case action
        when SpaceMakerActions::Shrink
          execute_shrink(action, graph, planned_partitions, disk_name)
        when SpaceMakerActions::Delete
          execute_delete(action, graph)
        else
          execute_wipe(action, graph)
        end
      end

      # Performs the action described by a {SpaceMakerActions::Shrink}
      #
      # @see #execute_action
      #
      # @param action [ProposalSpaceAction]
      # @param devicegraph [Devicegraph]
      # @param planned_partitions [Array<Planned::Partition>, nil]
      # @param disk_name [String, nil]
      # @return [Array<Integer>]
      def execute_shrink(action, devicegraph, planned_partitions, disk_name)
        log.info "SpaceMaker#execute_shrink - #{action}"

        if action.target_size.nil?
          part = devicegraph.find_device(action.sid)
          if planned_partitions
            resizing = resizing_size(part, planned_partitions, disk_name)
            action.target_size = resizing > part.size ? DiskSize.zero : part.size - resizing
          else
            # Mandatory resize
            action.target_size = part.size
          end
        end

        action.shrink(devicegraph)
      end

      # Performs the action described by a {SpaceMakerActions::Delete}
      #
      # @see #execute_action
      #
      # @param action [ProposalSpaceAction]
      # @param devicegraph [Devicegraph]
      # @return [Array<Integer>]
      def execute_delete(action, devicegraph)
        log.info "SpaceMaker#execute_delete - #{action}"
        action.delete(devicegraph, candidate_disk_names)
      end

      # Performs the action described by a {SpaceMakerActions::Wipe}
      #
      # @see #execute_action
      #
      # @param action [ProposalSpaceAction]
      # @param devicegraph [Devicegraph]
      # @return [Array<Integer>]
      def execute_wipe(action, devicegraph)
        log.info "SpaceMaker#execute_wipe - #{action}"
        action.wipe(devicegraph)
      end

      # Additional space that needs to be freed while resizing a partition in
      # order to reach the goal
      #
      # @return [DiskSize]
      def resizing_size(partition, planned_partitions, disk_name)
        spaces = free_spaces(disk_name)
        if disk_name && extra_disk_names.include?(disk_name)
          # Operating in a disk that is not a candidate_device, no need to make extra space for LVM
          return non_lvm_dist_calculator.resizing_size(partition, planned_partitions, spaces)
        end

        # As explained above, don't assume we will make space for LVM on non-candidate devices
        partitions = planned_partitions.reject { |p| extra_disk_names.include?(p.disk) }
        dist_calculator.resizing_size(partition, partitions, spaces)
      end

      # List of free spaces from the candidate devices in the new devicegraph
      #
      # @param disk [String, nil] optional disk name to restrict result to
      # @return [Array<FreeDiskSpace>]
      def free_spaces(disk = nil)
        disks_for(new_graph, disk).each_with_object([]) do |d, list|
          list.concat(d.as_not_empty { d.free_spaces })
        end
      end

      # List of free spaces from extra disks (see {#extra_disk_names})
      # @return [Array<FreeDiskSpace>]
      def extra_free_spaces
        extra_disk_names.flat_map { |d| free_spaces(d) }
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

      # Distribution calculator to use in special cases in which any implication related
      # to LVM must be ignored
      #
      # Used for example when operating in extra (non-candidate) disks
      #
      # @return [PartitionsDistributionCalculator]
      def non_lvm_dist_calculator
        @non_lvm_dist_calculator ||= PartitionsDistributionCalculator.new
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
