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

require "storage"

module Y2Storage
  module Proposal
    # Utility class to delete partitions from a devicegraph
    class PartitionKiller
      include Yast::Logger

      # Initialize.
      #
      # The optional parameter "disks" can be used to restrict the scope of the
      # collateral actions (see {#delete})
      #
      # @param devicegraph [Devicegraph]
      # @param disks [Array<String>] list of kernel-style device names
      def initialize(devicegraph, disks = nil)
        @devicegraph = devicegraph
        @disks = disks
      end

      # Deletes a given partition and other partitions that, as a consequence,
      # are not longer useful.
      #
      # @param device_name [String] device name of the partition
      # @return [Array<String>] device names of all the deleted partitions
      def delete(device_name)
        partition = find_partition(device_name)
        return [] unless partition

        if lvm_vg?(partition)
          delete_lvm_partitions(partition)
        else
          delete_partition(partition)
        end
      end

    protected

      attr_reader :devicegraph, :disks

      def find_partition(name)
        devicegraph.partitions.detect { |part| part.name == name }
      end

      # Deletes a given partition from its corresponding partition table.
      # If the partition was the only remaining logical one, it also deletes the
      # now empty extended partition
      #
      # @param partition [Partition]
      # @return [Array<String>] device names of all the deleted partitions
      def delete_partition(partition)
        log.info("Deleting partition #{partition.name} in device graph")
        if last_logical?(partition)
          log.info("It's the last logical one, so deleting the extended")
          delete_extended(partition.partition_table)
        else
          result = [partition.name]
          partition.partition_table.delete_partition(partition.name)
          result
        end
      end

      # Deletes the extended partition and all the logical ones
      #
      # @param partition_table [PartitionTable]
      # @return [Array<String>] device names of all the deleted partitions
      def delete_extended(partition_table)
        partitions = partition_table.partitions
        extended = partitions.detect { |part| part.type.is?(:extended) }
        logical_parts = partitions.select { |part| part.type.is?(:logical) }

        # This will delete the extended and all the logicals
        names = [extended.name] + logical_parts.map(&:name)
        partition_table.delete_partition(extended.name)
        names
      end

      # Checks whether the partition is the only logical one in the
      # partition_table
      #
      # @param partition [Partition]
      # @return [Boolean]
      def last_logical?(partition)
        return false unless partition.type.is?(:logical)

        partitions = partition.partition_table.partitions
        logical_parts = partitions.select { |part| part.type.is?(:logical) }
        logical_parts.size == 1
      end

      # Deletes the given partition and all other partitions in the candidate
      # disks that are part of the same LVM volume group
      #
      # Rationale: when deleting a partition that holds a PV of a given VG, we
      # are effectively killing the whole VG. It makes no sense to leave the
      # other PVs alive. So let's reclaim all the space.
      #
      # @param partition [Partition] A partition that is acting as
      #   LVM physical volume
      # @return [Array<String>] device names of all the deleted partitions
      def delete_lvm_partitions(partition)
        log.info "Deleting #{partition.name}, which is part of an LVM volume group"
        vg = partition.lvm_pv.lvm_vg
        partitions_to_delete = vg.lvm_pvs.map(&:plain_blk_device).select { |dev| dev.is?(:partition) }
        partitions_to_delete.select! { |p| disks.include?(p.partitionable.name) } if disks
        target_partitions = partitions_to_delete.map { |p| find_partition(p.name) }.compact
        log.info "These LVM partitions will be deleted: #{target_partitions.map(&:name)}"
        target_partitions.map { |p| delete_partition(p) }
      end

      # Checks whether the partition is part of a volume group
      #
      # @param partition [Partition]
      # @return [Boolean]
      def lvm_vg?(partition)
        !!(partition.lvm_pv && partition.lvm_pv.lvm_vg)
      end
    end
  end
end
