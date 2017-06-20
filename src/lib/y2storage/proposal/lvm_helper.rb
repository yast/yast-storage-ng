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
require "y2storage/exceptions"
require "y2storage/secret_attributes"

module Y2Storage
  module Proposal
    # Class to encapsulate the calculation of all the LVM-related values and
    # to generate the LVM setup needed to allocate a set of planned volumes
    class LvmHelper
      include Yast::Logger
      include SecretAttributes

      # This is just an estimation chosen to match libstorage hardcoded value
      # See LvmVg::Impl::calculate_region() in storage-ng
      USELESS_PV_SPACE = DiskSize.MiB(1)
      private_constant :USELESS_PV_SPACE

      # @!attribute encryption_password
      #   @return [String, nil] password used to encrypt the newly created
      #   physical volumes. If is nil, the PVs will not be encrypted.
      secret_attr :encryption_password

      # Constructor
      #
      # @param planned_lvs [Array<Planned::LvmLv>] volumes to allocate in LVM
      # @param encryption_password [String, nil] see {#encryption_password}
      def initialize(planned_lvs, encryption_password: nil)
        @planned_lvs = planned_lvs
        self.encryption_password = encryption_password
      end

      # Returns a copy of the original devicegraph in which all the logical
      # volumes (and the volume group, if needed) have been created.
      #
      # @param original_graph [Devicegraph]
      # @param pv_partitions [Array<String>] names of the newly created
      #     partitions that should be added as PVs to the volume group
      # @return [Devicegraph]
      def create_volumes(original_graph, pv_partitions = [])
        lvm_creator = LvmCreator.new(original_graph)
        # FIXME: it won't be needed in the future
        lvm_creator.create_volumes(volume_group, pv_partitions)
      end

      # Space that must be added to the final volume group in order to make
      # possible to allocate all the LVM planned volumes.
      #
      # This method takes into account the size of the extents and all the
      # related roundings.
      #
      # If there is a volume chosen to be reused (see {#volume_group}),
      # the method assumes all the space in that volume group can be reclaimed
      # for our purposes.
      def missing_space
        return DiskSize.zero if !planned_lvs || planned_lvs.empty?
        substract_reused_vg_size(volume_group.target_size)
      end

      # Space that must be added to the volume group to fulfill the max size
      # requirements for all the LVM planned volumes.
      #
      # This method takes into account the size of the extents and all the
      # related roundings.
      #
      # If there is a volume chosen to be reused (see {#volume_group}),
      # the method assumes all the space in that volume group can be reclaimed
      # for our purposes.
      def max_extra_space
        return DiskSize.zero if !planned_lvs || planned_lvs.empty?

        max = DiskSize.sum(planned_lvs.map(&:max_size), rounding: volume_group.extent_size)
        return max if max.unlimited? || !volume_group.reuse?

        substract_reused_vg_size(max)
      end

      # Device names of the initial physical volumes of the volume group to be
      # reused (see #volume_group)
      #
      # @return [Array<String>]
      def partitions_in_vg
        volume_group.pvs
      end

      # Min size that a partition must have to be useful as PV for the proposal
      #
      # @return [DiskSize]
      def min_pv_size
        volume_group.extent_size + useless_pv_space
      end

      # Part of a physical volume that can be used to allocate planned volumes
      #
      # @param size [DiskSize] total size of the partition
      # @return [DiskSize] usable size after substracting LVM overhead and
      #     space wasted by rounding
      def useful_pv_space(size)
        size -= useless_pv_space
        size.floor(volume_group.extent_size)
      end

      # Total size that a partition must have in order to provide the given
      # useful size to the proposal volume group. Inverse of #useful_pv_space
      # @see #useful_pv_space
      #
      # @param useful_size [DiskSize] size usable to allocate logical volumes
      # @return [DiskSize] real size of the partition
      def real_pv_size(useful_size)
        useful_size.ceil(volume_group.extent_size) + useless_pv_space
      end

      # Volumes groups that could be reused by the proposal, sorted by
      # preference.
      #
      # @param devicegraph [Devicegraph]
      # @return [Array<LvmVg>]
      def reusable_volume_groups(devicegraph)
        # FIXME: we currently have no mechanism to activate existing LUKS, so
        # there is no way we can re-use an encrypted LVM. Moreover, is still
        # undecided if we want to reuse encrypted LVMs at all.
        return [] if encrypt?

        vgs = devicegraph.lvm_vgs
        big_vgs, small_vgs = vgs.partition { |vg| vg.total_size >= volume_group.target_size }
        # Use #vg_name to ensure stable sorting
        big_vgs.sort_by! { |vg| [vg.total_size, vg.vg_name] }
        small_vgs.sort_by! { |vg| [vg.total_size, vg.vg_name] }
        small_vgs.reverse!
        big_vgs + small_vgs
      end

      # Portion of a newly created physical volume that couldn't be used to
      # allocate logical volumes because it would be reserved for LVM metadata
      # and other data structures.
      def useless_pv_space
        encrypt? ? USELESS_PV_SPACE + Planned::Partition.encryption_overhead : USELESS_PV_SPACE
      end

      # Checks whether an encrypted LVM was requested.
      #
      # @see #encryption_password
      #
      # @return [Boolean]
      def encrypt?
        !encryption_password.nil?
      end

      # Sets the VG to be reused
      #
      #
      def reused_volume_group=(vg)
        return @volume_group = nil if vg.nil?
        @volume_group = Y2Storage::Planned::LvmVg.from_real_vg(vg)
        @volume_group.lvs = planned_lvs
        @volume_group
      end

      # @return [LvmVg] Volume group that will be reused to allocate
      # the proposed volumes, deleting the existing logical volumes if necessary
      def volume_group
        @volume_group ||= Planned::LvmVg.new(lvs: planned_lvs)
      end

    protected

      attr_reader :planned_lvs

      def substract_reused_vg_size(size)
        vg_size = volume_group.total_size
        if vg_size < size
          size - vg_size
        else
          DiskSize.zero
        end
      end
    end
  end
end
