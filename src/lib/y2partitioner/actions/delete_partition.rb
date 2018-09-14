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
      def initialize(*args)
        super
        textdomain "storage"
      end

    private

      # Deletes the indicated partition (see {DeleteDevice#device})
      def delete
        log.info "deleting partition #{device}"
        parent_device = device.partitionable
        parent_device.partition_table.delete_partition(device)
        UIState.instance.select_row(parent_device)
      end

      # @see DeleteDevice#errors
      def errors
        errors = super + [implicit_partition_error]
        errors.compact
      end

      # Error when the partition is implicit
      #
      # @return [String, nil] nil if the partition is not implicit
      def implicit_partition_error
        return nil if !device.implicit?

        _("This is an implicit partition and cannot be deleted.")
      end

      # @see DeleteDevices#confirm
      #
      # @return [Boolean]
      def confirm
        if used_by_lvm?
          confirm_for_used_by_lvm
        elsif used_by_md?
          confirm_for_used_by_md
        else
          super
        end
      end

      # Confirmation when the partition belongs to a volume group
      #
      # @see ConfirmRecursiveDelete#confirm_recursive_delete
      # @see DeleteDevice#lvm_vg
      #
      # @return [Boolean]
      def confirm_for_used_by_lvm
        confirm_recursive_delete(
          device,
          _("Confirm Deleting Partition Used by LVM"),
          # TRANSLATORS: name is the name of the volume group that the partition
          #   belongs to (e.g., /dev/system)
          format(_("The selected partition is used by volume group \"%{name}\".\n" \
            "To keep the system in a consistent state, the following volume group\n" \
            "and its logical volumes will be deleted:"), name: lvm_vg.name),
          # TRANSLATORS: partition is the name of the partition to be deleted (e.g., /dev/sda1),
          #   and vg is the name of the volume group to be deleted (e.g., /dev/system)
          format(_("Delete partition \"%{partition}\" and volume group \"%{lvm_vg}\"?"),
            partition: device.name, lvm_vg: lvm_vg.name)
        )
      end

      # Confirmation when the partition belongs to a md raid
      #
      # @see ConfirmRecursiveDelete#confirm_recursive_delete
      # @see DeleteDevice#md
      #
      # @return [Boolean]
      def confirm_for_used_by_md
        confirm_recursive_delete(
          device,
          _("Confirm Deleting Partition Used by RAID"),
          # TRANSLATORS: name is the name of the partition to be deleted (e.g., /dev/sda1)
          format(_("The selected partition belongs to RAID \"%{name}\".\n" \
            "To keep the system in a consistent state, the following\n" \
            "RAID device will be deleted:"), name: md.name),
          # TRANSLATORS: partition is the name of the partition to be deleted (e.g., /dev/sda1),
          #   and md_raid is the name of the raid to be deleted (e.g., /dev/md/md1)
          format(_("Delete partition \"%{partition}\" and RAID \"%{md}\"?"),
            partition: device.name, md: md.name)
        )
      end
    end
  end
end
