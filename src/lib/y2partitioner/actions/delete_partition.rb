# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

require "yast"
require "y2partitioner/ui_state"
require "y2partitioner/actions/delete_device"

module Y2Partitioner
  module Actions
    # Action for deleting a partition
    #
    # @see DeleteDevice
    class DeletePartition < DeleteDevice
      # Confirmation message before performing the delete action
      def confirm
        if used_by_lvm?
          confirm_for_used_by_lvm
        elsif used_by_md_raid?
          confirm_for_used_by_md_raid
        else
          super
        end
      end

      # Deletes the indicated partition (see {DeleteDevice#device})
      def delete
        log.info "deleting partition #{device}"
        disk_device = device.partitionable
        disk_device.partition_table.delete_partition(device)
        UIState.instance.select_row(disk_device)
      end

    private

      # Checks whether the partition is used as physical volume
      #
      # @return [Boolean] true if partition belongs to a volume group; false otherwise
      def used_by_lvm?
        !vg.nil?
      end

      # Volume group that the partition belongs to
      #
      # @return [Y2Storage::LvmVg, nil] nil if the partition does not belong to
      #   a volume group
      def vg
        device.descendants.find { |d| d.is?(:lvm_vg) }
      end

      # Checks whether the partition is used by a md raid
      #
      # @return [Boolean] true if partition belongs to a md raid; false otherwise
      def used_by_md_raid?
        !md_raid.nil?
      end

      # Md Raid that the partition belongs to
      #
      # @return [Y2Storage::Md, nil] nil if the partition does not belong to a md raid
      def md_raid
        device.descendants.find { |d| d.is?(:md) }
      end

      # Confirmation when the partition belongs to a volume group
      #
      # @see DeleteDevice#dependent_devices
      # @see DeleteDevice#confirm_recursive_delete
      def confirm_for_used_by_lvm
        confirm_recursive_delete(
          dependent_devices,
          _("Confirm Deleting Partition Used by LVM"),
          # TRANSLATORS: name is the name of the volume group that the partition
          #   belongs to (e.g., /dev/system)
          format(_("The selected partition is used by volume group \"%{name}\".\n" \
            "To keep the system in a consistent state, the following volume group\n" \
            "and its logical volumes will be deleted:"), name: vg.name),
          # TRANSLATORS: partition is the name of the partition to be deleted (e.g., /dev/sda1),
          #   and vg is the name of the volume group to be deleted (e.g., /dev/system)
          format(_("Delete partition \"%{partition}\" and volume group \"%{vg}\"?"),
            partition: device.name, vg: vg.name)
        )
      end

      # Confirmation when the partition belongs to a md raid
      #
      # @see DeleteDevice#dependent_devices
      # @see DeleteDevice#confirm_recursive_delete
      def confirm_for_used_by_md_raid
        confirm_recursive_delete(
          dependent_devices,
          _("Confirm Deleting Partition Used by RAID"),
          # TRANSLATORS: name is the name of the partition to be deleted (e.g., /dev/sda1)
          format(_("The selected partition belongs to RAID \"%{name}\".\n" \
            "To keep the system in a consistent state, the following\n" \
            "RAID device will be deleted:"), name: md_raid.name),
          # TRANSLATORS: partition is the name of the partition to be deleted (e.g., /dev/sda1),
          #   and md_raid is the name of the raid to be deleted (e.g., /dev/md/md1)
          format(_("Delete partition \"%{partition}\" and RAID \"%{md_raid}\"?"),
            partition: device.name, md_raid: md_raid.name)
        )
      end
    end
  end
end
