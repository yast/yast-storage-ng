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

require "y2storage/proposal/autoinst_planner"

module Y2Storage
  module Proposal
    # This class converts an AutoYaST specification into a Planned::Vg in order
    # to set up a LVM volume group.
    class AutoinstVgPlanner
      include Y2Storage::Proposal::AutoinstPlanner

      # @!attribute [r] devicegraph
      #   @return [Devicegraph]
      # @!attribute [r] issues_list
      #
      attr_reader :devicegraph, :issues_list

      # Constructor
      #
      # @param devicegraph [Devicegraph] Devicegraph to be used as starting point
      # @param issues_list [AutoinstIssues::List] List of AutoYaST issues to register them
      def initialize(devicegraph, issues_list)
        @devicegraph = devicegraph
        @issues_list = issues_list
      end

      # Returns a planned volume group according to an AutoYaST specification
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   the volume group
      # @return [Planned::LvmVg] Planned volume group
      def planned_device(drive)
        vg = Y2Storage::Planned::LvmVg.new(volume_group_name: File.basename(drive.device))

        pools, regular = drive.partitions.partition(&:pool)
        (pools + regular).each_with_object(vg.lvs) do |lv_section, lvs|
          lv = planned_for_lv(drive, vg, lv_section)
          next if lv.nil? || lv.lv_type == LvType::THIN
          lvs << lv
        end

        vg.thin_pool_lvs.each { |v| add_thin_pool_lv_reuse(v, drive) }
        add_vg_reuse(vg, drive)
        vg
      end

    private

      # Returns a planned logical volume according to an AutoYaST specification
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   the volume group
      # @param vg [Planned::LvmVg] Planned volume group where the logical volume will
      #   be included
      # @param section [AutoinstProfile::PartitionSection] partition section describing
      #   the logical volume
      # @return [Planned::LvmLv,nil] Planned logical volume; nil if it could not be
      #   planned
      def planned_for_lv(drive, vg, section)
        # TODO: fix Planned::LvmLv.initialize
        lv = Y2Storage::Planned::LvmLv.new(nil, nil)
        lv.logical_volume_name = section.lv_name
        lv.lv_type = lv_type_for(section)
        add_stripes(lv, section)
        device_config(lv, section, drive)
        if section.used_pool
          return nil unless add_to_thin_pool(lv, vg, section)
        end
        add_lv_reuse(lv, vg.volume_group_name, section) if section.create == false
        assign_size_to_lv(vg, lv, section) ? lv : nil
      end

      # Set 'reusing' attributes for a logical volume
      #
      # This method modifies the first argument setting the values related to
      # reusing a logical volume (reuse and format).
      #
      # @param lv      [Planned::LvmLv] Planned logical volume
      # @param vg_name [String]         Volume group name to search for the logical volume to reuse
      # @param section [AutoinstProfile::PartitionSection] AutoYaST specification
      def add_lv_reuse(lv, vg_name, section)
        lv_to_reuse = find_lv_to_reuse(vg_name, section)
        return unless lv_to_reuse
        lv.logical_volume_name ||= lv_to_reuse.lv_name
        lv.filesystem_type ||= lv_to_reuse.filesystem_type
        add_device_reuse(lv, lv_to_reuse.name, section)
        add_device_reuse(lv.thin_pool, vg_name, section) if lv.thin_pool
      end

      # Set 'reusing' attributes for a volume group
      #
      # This method modifies the first argument setting the values related to
      # reusing a volume group (reuse and format).
      #
      # @param vg   [Planned::LvmVg] Planned volume group
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   the volume group
      def add_vg_reuse(vg, drive)
        vg.make_space_policy = drive.keep_unknown_lv ? :keep : :remove

        return unless vg.make_space_policy == :keep || vg.all_lvs.any?(&:reuse?)
        vg_to_reuse = find_vg_to_reuse(vg, drive)
        vg.reuse_name = vg_to_reuse.vg_name if vg_to_reuse
      end

      # Set 'reusing' attributes for a thin pool logical volume
      #
      # This method modifies the argument setting the values related to reusing
      # a thin logical volume (reuse_name). A thin pool will be planned to be
      # reused if any of its logical volumes will be reused.
      #
      # @param lv   [Planned::LvmLv] Thin logical volume
      def add_thin_pool_lv_reuse(lv, _drive)
        return unless lv.thin_lvs.any?(&:reuse?)
        lv_to_reuse = devicegraph.lvm_lvs.find { |v| lv.logical_volume_name == v.lv_name }
        lv.reuse_name = lv_to_reuse.name
      end

      # @param vg_name     [String]      Volume group name to search for the logical volume to reuse
      # @param part_section   [AutoinstProfile::PartitionSection] LV specification from AutoYaST
      def find_lv_to_reuse(vg_name, part_section)
        parent = find_lv_parent(vg_name, part_section)
        return if parent.nil?

        device =
          if part_section.lv_name
            parent.lvm_lvs.find { |v| v.lv_name == part_section.lv_name }
          elsif part_section.label
            parent.lvm_lvs.find { |v| v.filesystem_label == part_section.label }
          else
            issues_list.add(:missing_reuse_info, part_section)
            :missing_info
          end

        issues_list.add(:missing_reusable_device, part_section) unless device
        :missing_info == device ? nil : device
      end

      # @param vg_name     [String]      Volume group name to search for the logical volume
      # @param part_section   [AutoinstProfile::PartitionSection] LV specification from AutoYaST
      def find_lv_parent(vg_name, part_section)
        vg = devicegraph.lvm_vgs.find { |v| v.vg_name == vg_name }
        if vg.nil?
          issues_list.add(:missing_reusable_device, part_section)
          return
        end

        part_section.used_pool ? find_thin_pool_lv(vg, part_section) : vg
      end

      # @param vg          [Planned::LvmVg] Planned volume group
      # @param drive       [AutoinstProfile::DriveSection] drive section describing
      def find_vg_to_reuse(vg, drive)
        return nil unless vg.volume_group_name
        device = devicegraph.lvm_vgs.find { |v| v.vg_name == vg.volume_group_name }
        issues_list.add(:missing_reusable_device, drive) unless device
        device
      end

      # @param vg [LvmVg]   Logical volume group
      # @param part_section [AutoinstProfile::PartitionSection] LV specification from AutoYaST
      def find_thin_pool_lv(vg, part_section)
        lv = vg.lvm_lvs.find { |v| v.lv_name == part_section.used_pool }
        return lv if lv
        issues_list.add(:thin_pool_not_found, part_section)
        nil
      end

      # Assign LV size according to AutoYaST section
      #
      # @param vg         [Planned::LvmVg] Volume group
      # @param lv         [Planned::LvmLv] Logical volume
      # @param lv_section [AutoinstProfile::PartitionSection] AutoYaST section
      # @return [Boolean] true if the size was parsed and asssigned; false it was not valid
      def assign_size_to_lv(vg, lv, lv_section)
        size_info = parse_size(lv_section, vg.extent_size, DiskSize.unlimited)

        if size_info.nil?
          issues_list.add(:invalid_value, lv_section, :size)
          return false
        end

        if size_info.percentage
          lv.percent_size = size_info.percentage
        else
          lv.min_size = size_info.min
          lv.max_size = size_info.max
        end
        lv.weight = 1 if size_info.unlimited?

        true
      end

      # Return the logical volume type for a given section
      #
      # @param section [AutoinstProfile::PartitionSection] AutoYaST specification
      # @return [LvType] Logical volume type
      def lv_type_for(section)
        if section.pool
          LvType::THIN_POOL
        elsif section.used_pool
          LvType::THIN
        else
          LvType::NORMAL
        end
      end

      # Add a logical volume to a thin pool
      #
      # @param lv [Planned::LvmLv] Planned logical volume
      # @param vg [Planned::LvmVg] Planned volume group
      # @param section [AutoinstProfile::PartitionSection] AutoYaST specification
      # @return [Boolean] True if it was successfully added; false otherwise.
      def add_to_thin_pool(lv, vg, section)
        thin_pool = vg.thin_pool_lvs.find { |v| v.logical_volume_name == section.used_pool }
        if thin_pool.nil?
          issues_list.add(:thin_pool_not_found, section)
          return false
        end
        thin_pool.add_thin_lv(lv)
      end

      # Sets stripes related attributes
      #
      # @param lv      [Planned::LvmLv] Planned logical volume
      # @param section [AutoinstProfile::PartitionSection] partition section describing
      #   the logical volume
      def add_stripes(lv, section)
        lv.stripe_size = DiskSize.KiB(section.stripe_size.to_i) if section.stripe_size
        lv.stripes = section.stripes
      end
    end
  end
end
