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

module Y2Storage
  module DevicesLists
    # List of LVM logical volumes from a devicegraph
    class LvmLvsList < Base
      list_of ::Storage::LvmLv

      # Filesystems located in the logical volumes
      #
      # @return [FilesystemsList]
      def filesystems
        fs_list = list.map do |lv|
          begin
            lv.filesystem
          rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
            # No filesystem in the logical volume
            nil
          end
        end
        FilesystemsList.new(devicegraph, list: fs_list.compact)
      end

      # Volume groups containing the logical volumes
      #
      # @return [LvmVgsList]
      def lvm_vgs
        vgs = list.map(&:lvm_vg)
        vgs.uniq! { |vg| vg.sid }
        LvmVgsList.new(devicegraph, list: vgs)
      end

      alias_method :vgs, :lvm_vgs
      alias_method :volume_groups, :lvm_vgs
    end
  end
end
