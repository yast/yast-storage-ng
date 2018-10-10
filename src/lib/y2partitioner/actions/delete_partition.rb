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
    end
  end
end
