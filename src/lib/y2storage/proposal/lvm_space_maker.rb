# Copyright (c) [2017-2026] SUSE LLC
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

require "y2storage/disk_size"

module Y2Storage
  module Proposal
    # TODO
    class LvmSpaceMaker
      include Yast::Logger

      # Constructor
      #
      # @param volume_group [LvmVg] volume group to clean-up
      # @param planned_vg   [Planned::LvmVg] planned logical volume
      def initialize(volume_group, planned_vg)
        @volume_group = volume_group
        @planned_vg = planned_vg
      end

      # Makes space for planned logical volumes
      #
      # This method modifies the volume group received as first argument.
      #
      # When making free space, three different policies can be followed:
      #
      # * :needed: remove logical volumes until there's enough space for
      #            planned ones.
      # * :remove: remove all logical volumes.
      # * :keep:   keep all logical volumes.
      def provide_space
        return if planned_vg.make_space_policy == :keep

        case planned_vg.make_space_policy
        when :needed
          make_space_until_fit(volume_group, planned_vg.lvs)
        when :remove
          lvs_to_keep = planned_vg.all_lvs.select(&:reuse?).map(&:reuse_name)
          remove_logical_volumes(volume_group, lvs_to_keep)
        end
      end

      private

      # @return [LvmVg] volume group to clean-up
      attr_reader :volume_group

      # @reader [Planned::LvmVg] planned logical volume
      attr_reader :planned_vg

      # Makes sure the given volume group has enough free extends to allocate
      # all the planned volumes, by deleting the existing logical volumes.
      #
      # This method modifies the volume group received as first argument.
      #
      # FIXME: the current implementation does not guarantee than the freed
      # space is the minimum valid one.
      #
      # @param volume_group [LvmVg] volume group to modify
      def make_space_until_fit(volume_group, planned_lvs)
        space_size = DiskSize.sum(planned_lvs.map(&:min_size))
        missing = missing_vg_space(volume_group, space_size)
        while missing > DiskSize.zero
          lv_to_delete = delete_candidate(volume_group, missing)
          if lv_to_delete.nil?
            error_msg = "The volume group #{volume_group.vg_name} is not big enough"
            raise NoDiskSpaceError, error_msg
          end
          volume_group.delete_lvm_lv(lv_to_delete)
          missing = missing_vg_space(volume_group, space_size)
        end
      end

      # Remove all logical volumes from a volume group
      #
      # This method modifies the volume group received as a first argument.
      #
      # @param volume_group [LvmVg]         volume group to remove logical volumes from
      # @param lvs_to_keep  [Array<String>] name of logical volumes to keep
      def remove_logical_volumes(volume_group, lvs_to_keep)
        lvs_to_remove = volume_group.all_lvm_lvs.reject { |v| lvs_to_keep.include?(v.name) }
        lvs_to_remove.each { |v| volume_group.delete_lvm_lv(v) }
      end

      # Missing space in the volume group to fullfil a target
      #
      # @param volume_group [LvmVg]    Volume group
      # @param target_space [DiskSize] Required space
      def missing_vg_space(volume_group, target_space)
        available = volume_group.available_space
        if available > target_space
          DiskSize.zero
        else
          target_space - available
        end
      end

      # Best logical volume to delete next while trying to make space for the
      # planned volumes. It returns the smallest logical volume that would
      # fulfill the goal. If no LV is big enough, it returns the biggest one.
      def delete_candidate(volume_group, target_space)
        lvs = volume_group.lvm_lvs
        big_lvs = lvs.select { |lv| lv.size >= target_space }
        if big_lvs.empty?
          lvs.max_by(&:size)
        else
          big_lvs.min_by(&:size)
        end
      end
    end
  end
end
