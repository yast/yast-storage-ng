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

require "y2storage/storage_class_wrapper"
require "y2storage/mountable"
require "y2storage/manual_space_info"
require "y2storage/filesystems/type"

module Y2Storage
  module Filesystems
    # Abstract class to represent a filesystem, either a local (BlkFilesystem) or
    # a network one, like NFS.
    #
    # This is a wrapper for Storage::Filesystem
    class Base < Mountable
      wrap_class Storage::Filesystem,
        downcast_to: ["Filesystems::BlkFilesystem", "Filesystems::Nfs"]

      # @!method self.all(devicegraph)
      #   @param devicegraph [Devicegraph]
      #   @return [Array<Filesystems::Base>] all the filesystems in the given devicegraph
      storage_class_forward :all, as: "Filesystems::Base"

      # @!method type
      #   @return [Filesystems::Type]
      storage_forward :type, as: "Filesystems::Type"

      # @!method detect_space_info
      #   Information about the free space on a device.
      #
      #   The filesystem have to exists on the disk (i.e., in the probed
      #   devicegraph), this will mount it and then call the "df" command.
      #   Since both operations are expensive, caching this value is advised if
      #   it is needed repeatedly.
      #
      #   @raise [Storage::Exception] if the mentioned temporary mount operation fails
      #
      #   @return [SpaceInfo]
      storage_forward :detect_space_info, as: "SpaceInfo"

      # smarted space info including caching and handling not probed devices.
      #   @return [SpaceInfo]
      def space_info
        return @space_info if @space_info

        begin
          @space_info = detect_space_info
        rescue Storage::Exception
          # ok, we do not know it, so we try to detect ourself
          if is?(:blk_filesystem)
            size = blk_devices.map(&:size).reduce(:+)
            begin
              used = detect_resize_info.min_size
            rescue Storage::Exception
              used = DiskSize.new(0)
            end
            @space_info = ManualSpaceInfo.new(size, used)
          else
            @space_info = ManualSpaceInfo.new(DiskSize.new(0), DiskSize.new(0))
          end
        end
      end

      #   @return [Boolean]
      def in_network?
        return false
      end

    protected

      def types_for_is
        super << :filesystem
      end
    end
  end
end
