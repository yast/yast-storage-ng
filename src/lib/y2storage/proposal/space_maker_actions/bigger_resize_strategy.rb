# Copyright (c) [2023] SUSE LLC
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

require "y2storage/proposal/space_maker_actions/shrink"
require "y2storage/proposal/space_maker_actions/delete"
require "y2storage/proposal/space_maker_actions/wipe"

module Y2Storage
  module Proposal
    module SpaceMakerActions
      # Strategy for {SpaceMakerActions::List} used for the case in which the actions to perform are
      # explicitly configured as part of the proposal settings.
      class BiggerResizeStrategy
        # Constructor
        #
        # @param settings [ProposalSpaceSettings] proposal settings
        def initialize(settings, _disk_analyzer)
          @settings = settings
          @to_delete_mandatory = []
          @to_delete_optional = []
          @to_resize = []
        end

        # @param disk [Disk] see {List}
        def add_mandatory_actions(disk)
          devices = disk.partition_table? ? partitions(disk) : [disk]
          devices.select! { |d| configured?(d, :force_delete) }
          to_delete_mandatory.concat(devices)
        end

        # @param disk [Disk] see {List}
        # @param keep [Array<Integer>] see {List}
        def add_optional_actions(disk, keep, _lvm_helper)
          add_resize(disk)
          add_optional_delete(disk, keep)
        end

        # @return [Action, nil] nil if there are no more actions in the list
        def next
          source = source_for_next
          dev = send(source).first
          return unless dev

          return Shrink.new(dev) if source == :to_resize

          dev.is?(:partition) ? Delete.new(dev, related_partitions: false) : Wipe.new(dev)
        end

        # @param deleted_sids [Array<Integer>] see {List}
        def done(deleted_sids)
          send(source_for_next).shift
          cleanup(to_delete_mandatory, deleted_sids)
          cleanup(to_delete_optional, deleted_sids)
          cleanup(to_resize, deleted_sids)
        end

        private

        # @return [ProposalSpaceSettings] proposal settings for making space
        attr_reader :settings

        # @return [Array<BlkDevice>] list of devices to be deleted or emptied (mandatory)
        attr_reader :to_delete_mandatory

        # @return [Array<BlkDevice>] list of devices to be deleted or emptied (optionally)
        attr_reader :to_delete_optional

        # @return [Array<Partition>] list of partitions to be shrunk
        attr_reader :to_resize

        # @see #add_optional_actions
        # @param disk [Disk]
        def add_resize(disk)
          return unless disk.partition_table?

          partitions = partitions(disk).select { |p| configured?(p, :resize) }
          return if partitions.empty?

          @to_resize = (to_resize + partitions).sort { |a, b| preferred_resize(a, b) }
        end

        # Compares two partitions to decide which one should be resized first
        #
        # @param part1 [Partition]
        # @param part2 [Partition]
        def preferred_resize(part1, part2)
          result = part2.recoverable_size <=> part1.recoverable_size
          return result unless result.zero?

          # Just to ensure stable sorting between different executions in case of draw
          part1.name <=> part2.name
        end

        # @see #add_optional_actions
        #
        # @param disk [Disk]
        # @param keep [Array<Integer>]
        def add_optional_delete(disk, keep)
          if disk.partition_table?
            partitions = partitions(disk).select { |p| configured?(p, :delete) }
            partitions.reject! { |p| keep.include?(p.sid) }
            to_delete_optional.concat(partitions.sort { |a, b| preferred_delete(a, b) })
          elsif configured?(disk, :delete)
            to_delete_optional << disk
          end
        end

        # Compares two partitions to decide which one should be deleted first
        #
        # @param part1 [Partition]
        # @param part2 [Partition]
        def preferred_delete(part1, part2)
          # Mimic order from the auto strategy. We might consider other approaches in the future.
          part2.region.start <=> part1.region.start
        end

        # Whether the given action is configured for the given device at the proposal settings
        #
        # @see ProposalSpaceSettings#actions
        #
        # @param device [BlkDevice]
        # @param action [Symbol] :force_delete, :delete or :resize
        # @return [Boolean]
        def configured?(device, action)
          settings.actions[device.name]&.to_sym == action
        end

        # Removes devices with the given sids from a collection
        #
        # @param collection [Array<BlkDevice>]
        # @param deleted_sids [Array<Integer>]
        def cleanup(collection, deleted_sids)
          collection.delete_if { |d| deleted_sids.include?(d.sid) }
        end

        # Collection for the next action
        #
        # @return [Symbol]
        def source_for_next
          if to_delete_mandatory.any?
            :to_delete_mandatory
          elsif to_resize.any?
            :to_resize
          else
            :to_delete_optional
          end
        end

        # Relevant partitions for the given disk
        def partitions(disk)
          disk.partitions.reject { |part| part.type.is?(:extended) }
        end
      end
    end
  end
end
