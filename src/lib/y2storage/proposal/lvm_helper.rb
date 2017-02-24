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
require "y2storage/disk_size"
require "y2storage/refinements"
require "y2storage/proposal/exceptions"
require "y2storage/proposal/encrypter"
require "y2storage/proposal/proposed_lv"
require "y2storage/secret_attributes"

module Y2Storage
  class Proposal
    # Class to encapsulate the calculation of all the LVM-related values and
    # to generate the LVM setup needed to allocate a set of planned volumes
    class LvmHelper
      using Refinements::Devicegraph
      using Refinements::DevicegraphLists
      include Yast::Logger
      include SecretAttributes

      DEFAULT_VG_NAME = "system"
      DEFAULT_LV_NAME = "lv"
      DEFAULT_EXTENT_SIZE = DiskSize.MiB(4)
      private_constant :DEFAULT_VG_NAME, :DEFAULT_LV_NAME, :DEFAULT_EXTENT_SIZE
      # This is just an estimation chosen to match libstorage hardcoded value
      # See LvmVg::Impl::calculate_region() in storage-ng
      USELESS_PV_SPACE = DiskSize.MiB(1)
      private_constant :USELESS_PV_SPACE

      # @return [Storage::LvmVg] Volume group that will be reused to allocate
      # the proposed volumes, deleting the existing logical volumes if necessary
      attr_accessor :reused_volume_group

      # @!attribute encryption_password
      #   @return [String, nil] password used to encrypt the newly created
      #   physical volumes. If is nil, the PVs will not be encrypted.
      secret_attr :encryption_password

      # Constructor
      #
      # @param planned_volumes [PlannedVolumesList] volumes to allocate in LVM
      # @param encryption_password [String, nil] @see #encryption_password
      def initialize(proposed_lvs, encryption_password: nil)
        @proposed_lvs = proposed_lvs
        self.encryption_password = encryption_password
      end

      # Returns a copy of the original devicegraph in which all the logical
      # volumes (and the volume group, if needed) have been created.
      #
      # @param original_graph [Storage::Devicegraph]
      # @param pv_partitions [Array<String>] names of the newly created
      #     partitions that should be added as PVs to the volume group
      # @return [Storage::Devicegraph]
      def create_volumes(original_graph, pv_partitions = [])
        new_graph = original_graph.duplicate
        return new_graph if proposed_lvs.empty?

        vg = reused_volume_group ? find_reused_vg(new_graph) : create_volume_group(new_graph)

        assign_physical_volumes!(vg, pv_partitions, new_graph)
        make_space!(vg)
        create_logical_volumes!(vg)

        new_graph
      end

      # Space that must be added to the final volume group in order to make
      # possible to allocate all the LVM planned volumes.
      #
      # This method takes into account the size of the extents and all the
      # related roundings.
      #
      # If there is a volume chosen to be reused (@see #reused_volume_group),
      # the method assumes all the space in that volume group can be reclaimed
      # for our purposes.
      def missing_space
        return DiskSize.zero if !proposed_lvs || proposed_lvs.empty?
        return target_size unless reused_volume_group

        substract_reused_vg_size(target_size)
      end

      # Space that must be added to the volume group to fulfill
      # PlannedVolumesList#max_disk_size for all the LVM planned volumes.
      #
      # This method takes into account the size of the extents and all the
      # related roundings.
      #
      # If there is a volume chosen to be reused (@see #reused_volume_group),
      # the method assumes all the space in that volume group can be reclaimed
      # for our purposes.
      def max_extra_space
        return DiskSize.zero if !proposed_lvs || proposed_lvs.empty?

        max = ProposedLv.max_disk_size(proposed_lvs, rounding: extent_size)
        return max if max.unlimited? || !reused_volume_group

        substract_reused_vg_size(max)
      end

      # Device names of the initial physical volumes of the volume group to be
      # reused (see #reused_volume_group)
      #
      # @return [Array<String>]
      def partitions_in_vg
        return [] unless reused_volume_group
        reused_volume_group.lvm_pvs.to_a.map { |pv| pv.blk_device.name }
      end

      # Min size that a partition must have to be useful as PV for the proposal
      #
      # @return [DiskSize]
      def min_pv_size
        extent_size + useless_pv_space
      end

      # Part of a physical volume that can be used to allocate planned volumes
      #
      # @param size [DiskSize] total size of the partition
      # @return [DiskSize] usable size after substracting LVM overhead and
      #     space wasted by rounding
      def useful_pv_space(size)
        size -= useless_pv_space
        size.floor(extent_size)
      end

      # Total size that a partition must have in order to provide the given
      # useful size to the proposal volume group. Inverse of #useful_pv_space
      # @see #useful_pv_space
      #
      # @param useful_size [DiskSize] size usable to allocate logical volumes
      # @return [DiskSize] real size of the partition
      def real_pv_size(useful_size)
        useful_size.ceil(extent_size) + useless_pv_space
      end

      # Volumes groups that could be reused by the proposal, sorted by
      # preference.
      #
      # @param devicegraph [Storage::Devicegraph]
      # @return [Array<Storage::LvmVg>]
      def reusable_volume_groups(devicegraph)
        # FIXME: we currently have no mechanism to activate existing LUKS, so
        # there is no way we can re-use an encrypted LVM. Moreover, is still
        # undecided if we want to reuse encrypted LVMs at all.
        return [] if encrypt?

        vgs = devicegraph.volume_groups
        big_vgs, small_vgs = vgs.partition { |vg| total_size(vg) >= target_size }
        # Use #vg_name to ensure stable sorting
        big_vgs.sort_by! { |vg| [total_size(vg), vg.vg_name] }
        small_vgs.sort_by! { |vg| [total_size(vg), vg.vg_name] }
        small_vgs.reverse!
        big_vgs + small_vgs
      end

      # Portion of a newly created physical volume that couldn't be used to
      # allocate logical volumes because it would be reserved for LVM metadata
      # and other data structures.
      def useless_pv_space
        encrypt? ? USELESS_PV_SPACE + encrypter.device_overhead : USELESS_PV_SPACE
      end

      # Checks whether an encrypted LVM was requested.
      #
      # @see #encryption_password
      #
      # @return [Boolean]
      def encrypt?
        !encryption_password.nil?
      end

    protected

      attr_reader :proposed_lvs

      def extent_size
        if reused_volume_group
          DiskSize.new(reused_volume_group.extent_size)
        else
          DEFAULT_EXTENT_SIZE
        end
      end

      def target_size
        ProposedLv.disk_size(proposed_lvs, rounding: extent_size)
      end

      def substract_reused_vg_size(size)
        vg_size = total_size(reused_volume_group)
        if vg_size < size
          size - vg_size
        else
          DiskSize.zero
        end
      end

      def find_reused_vg(devicegraph)
        devicegraph.lvm_vgs.with(sid: reused_volume_group.sid).first
      end

      def create_volume_group(devicegraph)
        name = available_name(DEFAULT_VG_NAME, devicegraph)
        Storage::LvmVg.create(devicegraph, name)
      end

      # Extends the given volume group by adding as physical volumes the
      # partitions in the given list.
      #
      # This method modifies the volume group received as first argument.
      #
      # @param volume_group [Storage::LvmVg] volume group to extend
      # @param part_names [Array<String>] device names of the partitions
      # @param devicegraph [Storage::Devicegraph] to fetch the partitions
      def assign_physical_volumes!(volume_group, part_names, devicegraph)
        devicegraph.partitions.with(name: part_names).each do |partition|
          device = encrypt? ? partition.encryption : partition
          volume_group.add_lvm_pv(device)
        end
      end

      # Makes sure the given volume group has enough free extends to allocate
      # all the planned volumes, by deleting the existing volume groups.
      #
      # This method modifies the volume group received as first argument.
      #
      # FIXME: the current implementation does not guarantee than the freed
      # space is the minimum valid one.
      #
      # @param volume_group [Storage::LvmVg] volume group to modify
      def make_space!(volume_group)
        space_size = ProposedLv.disk_size(proposed_lvs)
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

      # Creates a logical volume for each planned volume.
      #
      # This method modifies the volume group received as first argument.
      #
      # @param volume_group [Storage::LvmVg] volume group to modify
      def create_logical_volumes!(volume_group)
        vg_size = available_space(volume_group)
        distribute_space!(vg_size, rounding: extent_size)
        proposed_lvs.each do |lv|
          create_logical_volume(volume_group, lv)
        end
      end

      def create_logical_volume(volume_group, proposed_lv)
        name = proposed_lv.logical_volume_name || DEFAULT_LV_NAME
        name = available_name(name, volume_group)
        lv = volume_group.create_lvm_lv(name, proposed_lv.disk_size.to_i)
        proposed_lv.create_filesystem(lv)
      end

      # Best logical volume to delete next while trying to make space for the
      # planned volumes. It returns the smallest logical volume that would
      # fulfill the goal. If no LV is big enough, it returns the biggest one.
      def delete_candidate(volume_group, target_space)
        target_space = target_space.to_i
        lvs = volume_group.lvm_lvs.to_a
        big_lvs = lvs.select { |lv| lv.size >= target_space }
        if big_lvs.empty?
          lvs.max_by { |lv| lv.size }
        else
          big_lvs.min_by { |lv| lv.size }
        end
      end

      def missing_vg_space(volume_group, target_space)
        available = available_space(volume_group)
        if available > target_space
          DiskSize.zero
        else
          target_space - available
        end
      end

      def available_space(volume_group)
        DiskSize.new(volume_group.number_of_free_extents * volume_group.extent_size)
      end

      def total_size(volume_group)
        DiskSize.new(volume_group.number_of_extents * volume_group.extent_size)
      end

      # Returns the name that is available taking original_name as a base. If
      # the name is already taken, the returned name will have a number
      # appended.
      #
      # @param original_name [String]
      # @param root [Storage::Devicegraph, Storage::LvmVg] if root is a
      #   devicegraph, the name is considered a VG name. If root is a VG, the
      #   name is for a logical volume.
      # @return [String]
      def available_name(original_name, root)
        return original_name unless name_taken?(original_name, root)

        suffix = 0
        name = "#{original_name}#{suffix}"
        while name_taken?(name, root)
          suffix += 1
          name = "#{original_name}#{suffix}"
        end
        name
      end

      def name_taken?(name, root)
        if root.is_a? Storage::Devicegraph
          root.vgs.with(vg_name: name).any?
        else
          root.lvm_lvs.to_a.any? { |lv| lv.lv_name == name }
        end
      end

      def encrypter
        @encrypter ||= Encrypter.new
      end

      # FIXME

      # Returns a copy of the list in which the given space has been distributed
      # among the volumes, distributing the extra space (beyond the target size)
      # according to the weight and max size of each volume.
      #
      # @raise [RuntimeError] if the given space is not enough to reach the target
      #     size for all volumes
      #
      # If the optional argument rounding is used, space will be distributed
      # always in blocks of the specified size.
      #
      # @param space_size [DiskSize]
      # @param rounding [DiskSize, nil] min block size to distribute. Mainly used
      #     to distribute space among LVs honoring the PE size of the LVM
      # @param min_grain [DiskSize, nil] minimal grain of the disk where the space
      #     is located. It only makes sense when distributing space among
      #     partitions.
      # @return [PlannedVolumesList] list containing volumes with an adjusted
      #     value for PlannedVolume#disk_size
      def distribute_space!(space_size, rounding: nil, min_grain: nil)
        required_size = ProposedLv.disk_size(proposed_lvs) 
        raise RuntimeError if space_size < required_size

        rounding ||= min_grain
        rounding ||= DiskSize.new(1)

        proposed_lvs.each { |lv| lv.disk_size = lv.disk_size.ceil(rounding) }
        adjust_size_to_last_slot!(proposed_lvs.last, space_size, min_grain) if min_grain

        extra_size = space_size - ProposedLv.total_disk_size(proposed_lvs)
        unused = distribute_extra_space!(extra_size, rounding)
        proposed_lvs.last.disk_size += unused if min_grain && unused < min_grain

        proposed_lvs
      end

      def adjust_size_to_last_slot!(lv, space_size, min_grain)
        adjusted_size = adjusted_size_after_ceil(lv, space_size, min_grain)
        target_size = lv.disk_size
        lv.disk_size = adjusted_size unless adjusted_size < target_size
      end

      def adjusted_size_after_ceil(lv, space_size, min_grain)
        mod = space_size % min_grain
        last_slot_size = mod.zero? ? min_grain : mod
        return lv.disk_size if last_slot_size == min_grain

        missing = min_grain - last_slot_size
        lv.disk_size - missing
      end

      # @return [DiskSize] Surplus space that could not be distributed
      def distribute_extra_space!(extra_size, rounding)
        candidates = proposed_lvs
        while distributable?(extra_size, rounding)
          candidates = extra_space_candidates(candidates)
          return extra_size if candidates.empty?
          return extra_size if ProposedLv.total_weight(candidates).zero?
          log.info("Distributing #{extra_size} extra space among #{candidates.size} volumes")

          assigned_size = DiskSize.zero
          total_weight = ProposedLv.total_weight(candidates)
          candidates.each do |lv|
            lv_extra = lv_extra_size(lv, extra_size, total_weight, assigned_size, rounding)
            lv.disk_size += lv_extra
            log.info("Distributing #{lv_extra} to #{lv.mount_point}; now #{lv.disk_size}")
            assigned_size += lv_extra
          end
          extra_size -= assigned_size
        end
        log.info("Could not distribute #{extra_size}") unless extra_size.zero?
        extra_size
      end

      # Volumes that may grow when distributing the extra space
      #
      # @param volumes [PlannedVolumesList] initial set of all volumes
      # @return [PlannedVolumesList]
      def extra_space_candidates(lvs)
        lvs.select { |lv| lv.disk_size < lv.max_disk_size}
      end

      def distributable?(size, rounding)
        size >= rounding
      end

      # Extra space to be assigned to a volume
      #
      # @param volume [PlannedVolume] volume to enlarge
      # @param total_size [DiskSize] free space to be distributed among
      #    involved volumes
      # @param total_weight [Float] sum of the weights of all involved volumes
      # @param assigned_size [DiskSize] space already distributed to other volumes
      # @param rounding [DiskSize] size to round up
      #
      # @return [DiskSize]
      def lv_extra_size(lv, total_size, total_weight, assigned_size, rounding)
        available_size = total_size - assigned_size

        extra_size = total_size * (lv.weight / total_weight)
        extra_size = extra_size.ceil(rounding)
        extra_size = available_size.floor(rounding) if extra_size > available_size

        new_size = extra_size + lv.disk_size
        if new_size > lv.max_disk_size
          # Increase just until reaching the max size
          lv.max_disk_size - lv.disk_size
        else
          extra_size
        end
      end

    end
  end
end
