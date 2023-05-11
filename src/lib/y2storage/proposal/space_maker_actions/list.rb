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

require "y2storage/proposal/space_maker_prospects"

module Y2Storage
  module Proposal
    module SpaceMakerActions
      # A set of actions to be executed by SpaceMaker
      #
      # This class is responsible of selecting which prospect action would be the next to be
      # performed by SpaceMaker, both at the beginning of the process (mandatory actions) and during
      # the iterative process done to find enough space (optional actions).
      #
      # In this original implementation is basically a wrapper around {SpaceMakerProspects::List},
      # but in the future it will implement different strategies to calculate and sort the actions.
      class List
        # Initialize.
        #
        # @param settings [ProposalSpaceSettings] proposal settings
        # @param disk_analyzer [DiskAnalyzer] information about existing partitions
        def initialize(settings, disk_analyzer)
          @settings = settings
          @disk_analyzer = disk_analyzer
          @prospects = SpaceMakerProspects::List.new(settings, disk_analyzer)
          @mandatory = []
        end

        # Adds mandatory actions to be performed at the beginning of the process
        #
        # @see SpaceMaker#prepare_devicegraph
        #
        # In the case of the traditional YaST strategy for making space, that corresponds to
        # deleting all partitions explicitly marked for removal in the proposal settings, i.e.
        # all the partitions belonging to one of the types with delete_mode set to :all.
        #
        # @see ProposalSettings#windows_delete_mode
        # @see ProposalSettings#linux_delete_mode
        # @see ProposalSettings#other_delete_mode
        #
        # @param disk [Disk] disk to act upon
        def add_mandatory_actions(disk)
          mandatory.concat(prospects.unwanted_partition_prospects(disk))
        end

        # Adds optional actions to be performed if needed until the goal is reached
        #
        # @see SpaceMaker#provide_space
        #
        # @param disk [Disk] disk to act upon
        # @param keep [Array<Integer>] sids of partitions that should not be deleted
        # @param lvm_helper [Proposal::LvmHelper] contains information about the
        #     planned LVM logical volumes and how to make space for them
        def add_optional_actions(disk, keep, lvm_helper)
          prospects.add_prospects(disk, lvm_helper, keep)
        end

        # Next action to be performed by SpaceMaker
        #
        # @return [Action, nil] nil if there are no more actions in the list
        def next
          next_prospect&.action
        end

        # Marks the action currently reported by {#next} as completed, so it will not be longer
        # returned by subsequent calls to {#next}
        #
        # @param deleted_sids [Array<Integer>] sids of devices that are not longer available as
        #   a side effect of completing the action
        def done(deleted_sids = [])
          if mandatory.any?
            mandatory.shift
            return
          end

          prospects.next_available_prospect.available = false
          prospects.mark_deleted(deleted_sids)
        end

        private

        # @return [Array<Action>] list of mandatory actions to be executed
        attr_reader :mandatory

        # @return [SpaceMakerProspects::List] optional actions to be executed if needed
        attr_reader :prospects

        # @see #next
        def next_prospect
          return @mandatory.first unless @mandatory.empty?

          prospects.next_available_prospect
        end
      end
    end
  end
end
