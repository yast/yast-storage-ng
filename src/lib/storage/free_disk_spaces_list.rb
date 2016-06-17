#
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

require "storage/free_disk_space"
require "storage/disk_size"
require "storage/devices_list"
require "storage/refinements/disk"

module Yast
  module Storage
    # List of free spaces from a devicegraph
    class FreeDiskSpacesList < DevicesList
      list_of FreeDiskSpace

      using Refinements::Disk

      # Sum of the sizes of all the spaces
      #
      # @return [DiskSize]
      def disk_size
        list.map(&:disk_size).reduce(DiskSize.zero, :+)
      end

    protected

      def full_list
        disks = devicegraph.all_disks.to_a
        disks.reduce([]) { |sum, disk| sum + disk.free_spaces }
      end
    end
  end
end
