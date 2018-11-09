#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

require "y2storage/proposal/space_maker_prospects/delete_partition"
require "y2storage/proposal/space_maker_prospects/resize_partition"
require "y2storage/proposal/space_maker_prospects/wipe_disk"

module Y2Storage
  module Proposal
    module SpaceMakerProspects
      # A set of prospect actions SpaceMaker can perform to reach its goal
      class List
        include Yast::Logger

        # @param settings [ProposalSettings] see {#settings}
        # @param disk_analyzer [DiskAnalyzer] see {#analyzer}
        def initialize(settings, disk_analyzer)
          @settings = settings
          @analyzer = disk_analyzer

          @all_delete_partition_entries = {
            linux:   [],
            windows: [],
            other:   []
          }

          @resize_partition_without_linux_entries = []
          @resize_partition_with_linux_entries = []
          @wipe_disk_entries = []
        end

        # Adds to the set all the prospect actions for the given disk
        #
        # @param disk [Disk] disk to act upon
        # @param lvm_helper [Proposal::LvmHelper] contains information about the
        #     planned LVM logical volumes and how to make space for them
        # @param keep [Array<Integer>] sids of partitions that should not be deleted
        def add_entries(disk, lvm_helper, keep = [])
          add_delete_partition_entries(disk, keep)
          add_resize_entries(disk)
          add_wipe_entries(disk, lvm_helper)
        end

        # Adds to the set all the prospect actions about deleting partitions of
        # the given disk (i.e. entries of type {SpaceMakerProspects::DeletePartition})
        #
        # @param disk [Disk] disk to act upon
        # @param keep [Array<Integer>] sids of partitions that should not be deleted
        def add_delete_partition_entries(disk, keep = [])
          entries = delete_prospects_for_disk(disk, keep)
          linux, non_linux = entries.partition { |e| e.partition_type == :linux }
          windows, other = non_linux.partition { |e| e.partition_type == :windows }

          delete_partition_entries(:linux).concat(linux.sort_by(&:region_start).reverse)
          delete_partition_entries(:windows).concat(windows.sort_by(&:region_start).reverse)
          delete_partition_entries(:other).concat(other.sort_by(&:region_start).reverse)
        end

        # Entries of type #{SpaceMakerProspects::DeletePartition}
        #
        # @param type [Symbol, nil] optional type to filter the result
        def delete_partition_entries(type = nil)
          if type.nil?
            @all_delete_partition_entries.values.flatten
          else
            @all_delete_partition_entries[type]
          end
        end

        # Next prospect action that should be executed by SpaceMaker
        #
        # @return [SpaceMakerProspects::Base, nil] nil if there are no more
        #   available prospects
        def next_available_entry
          # As long as there are non-Windows partitions to delete, we refuse to
          # resize Windows systems that share disk with a Linux. See
          # #next_resize_partition for the rationale.
          resize = next_resize_partition(allow_linux_in_disk: false)
          return resize if resize

          delete = next_delete_partition
          return delete if delete && delete.partition_type != :windows

          wipe = next_wipe_disk
          return wipe if wipe

          # The next partition to delete would be a Windows one. In that case,
          # reconsider resizing any Windows partition (no matter whether there
          # is a Linux in the disk)
          resize = next_resize_partition
          return resize if resize

          # Last resort, deleting Windows partitions (if any)
          delete
        end

        # Marks all the prospect actions on the partitions with the given sids
        # to not be available any longer
        #
        # @param sids [Array<Integer>]
        def mark_deleted(sids)
          prospects = delete_partition_entries + resize_partition_entries
          prospects.select { |i| sids.include?(i.sid) }.each do |affected|
            affected.available = false
          end
        end

      private

        # @return [DiskAnalyzer] disk analyzer with information about the
        # initial layout of the system
        attr_reader :analyzer

        # @return [ProposalSettings]
        attr_reader :settings

        # @return [Array<WipeDisk>]
        attr_reader :wipe_disk_entries

        # Next available prospect of type #{DeletePartition}
        #
        # @return [DeletePartition, nil] nil if there are no available prospect
        #   actions
        def next_delete_partition
          delete_partition_entries(:linux).find(&:available?) ||
            delete_partition_entries(:other).find(&:available?) ||
            delete_partition_entries(:windows).find(&:available?)
        end

        # Next available prospect of type #{ResizePartition}
        #
        # If possible, SpaceMaker tries to avoid resizing Windows systems that
        # share its disk with Linux. That's why an optional argument is provided
        # to exclude such prospect actions.
        #
        # Rationale: users having a Windows and a Linux in the same disk have
        # likely already resized Windows once (when installing that Linux).
        # So they probably don't want to resize it again.
        #
        # @param allow_linux_in_disk [Boolean] whether to take into account
        #   target partitions that are in a disk which had also a Linux
        #   partition. See {PartitionProspect#linux_in_disk?}.
        # @return [ResizePartition, nil] nil if there are no available prospect
        #   actions
        def next_resize_partition(allow_linux_in_disk: true)
          entry = next_useful_resize(@resize_partition_without_linux_entries)
          if entry.nil? && allow_linux_in_disk
            entry = next_useful_resize(@resize_partition_with_linux_entries)
          end
          entry
        end

        # Next available prospect of type #{WipeDisk}
        #
        # @return [WipeDisk, nil] nil if there are no available prospect actions
        def next_wipe_disk
          wipe_disk_entries.find(&:available?)
        end

        # Adds to the set all the prospect actions about resizing partitions of
        # the given disk (i.e. entries of type {SpaceMakerProspects::ResizePartition})
        #
        # @param disk [Disk] disk to act upon
        def add_resize_entries(disk)
          part_names = analyzer.windows_partitions(disk.name).map(&:name)
          return if part_names.empty?

          log.info("Evaluating the following Windows partitions: #{part_names}")
          prospects = disk.partitions.select { |p| part_names.include?(p.name) }.map do |part|
            SpaceMakerProspects::ResizePartition.new(part, analyzer)
          end
          prospects.select! { |action| action.allowed?(settings) }
          with_linux, without_linux = prospects.partition(&:linux_in_disk?)

          @resize_partition_without_linux_entries.concat(without_linux)
          @resize_partition_with_linux_entries.concat(with_linux)
        end

        # If possible, adds to the set a prospect action about cleaning the disk
        # content (i.e. entries of type {SpaceMakerProspects::WipeDisk})
        #
        # @param disk [Disk] disk to act upon
        # @param lvm_helper [Proposal::LvmHelper] contains information about the
        #     planned LVM logical volumes and how to make space for them
        def add_wipe_entries(disk, lvm_helper)
          log.info "Checking if the disk #{disk.name} has a partition table"

          return unless disk.has_children? && disk.partition_table.nil?
          log.info "Found something that is not a partition table"

          if disk.descendants.any? { |dev| lvm_helper.vg_to_reuse?(dev) }
            log.info "Not cleaning up #{disk.name} because its VG must be reused"
            return
          end

          @wipe_disk_entries << SpaceMakerProspects::WipeDisk.new(disk)
        end

        def delete_prospects_for_disk(disk, keep = [])
          partitions = disk.partitions.reject { |part| part.type.is?(:extended) }

          prospects = partitions.map do |part|
            SpaceMakerProspects::DeletePartition.new(part, analyzer)
          end
          prospects.select { |action| action.allowed?(settings, keep) }
        end

        def next_useful_resize(entries)
          entries.select { |e| e.available? && !e.recoverable_size.zero? }
                 .sort_by(&:recoverable_size).last
        end

        def resize_partition_entries
          @resize_partition_without_linux_entries + @resize_partition_with_linux_entries
        end
      end
    end
  end
end
