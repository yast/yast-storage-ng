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

require "storage"
require "y2storage/devices_lists/base"
require "y2storage/devices_lists/lvm_pvs_list"
require "y2storage/devices_lists/lvm_lvs_list"

module Y2Storage
  module DevicesLists
    # List of LVM volume groups from a devicegraph
    class LvmVgsList < Base
      list_of ::Storage::LvmVg

      # Physical volumes included in any of the volume groups
      #
      # @return [LvmPvsList]
      def lvm_pvs
        pvs_list = list.reduce([]) { |sum, vg| sum.concat(vg.lvm_pvs.to_a) }
        LvmPvsList.new(devicegraph, list: pvs_list)
      end

      alias_method :pvs, :lvm_pvs
      alias_method :physical_volumes, :lvm_pvs

      # Logical volumes included in any of the volume groups
      #
      # @return [LvmLvList]
      def lvm_lvs
        lvs_list = list.reduce([]) { |sum, vg| sum.concat(vg.lvm_lvs.to_a) }
        LvmLvsList.new(devicegraph, list: lvs_list)
      end

      alias_method :lvs, :lvm_lvs
      alias_method :logical_volumes, :lvm_lvs

      # Filesystems present in any of the volume groups
      #
      # @return [FilesystemsList]
      def filesystems
        lvm_lvs.filesystems
      end
    end
  end
end
