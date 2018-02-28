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

      # smart detection of free space
      # it try to use detect_space_info and cache it. But if it failed, it try
      # to compute it from detect_resize_info. If it failed or filesystem is
      # not block filesystem, then it return zero size.
      #
      # @return [DiskSize]
      def free_space
        return @free_space if @free_space

        begin
          @free_space = detect_space_info.free
        rescue Storage::Exception
          # ok, we do not know it, so we try to detect ourself
          @free_space = detect_free_space
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

      FREE_SPACE_FALLBACK = DiskSize.new(0)
      def detect_free_space
        return FREE_SPACE_FALLBACK unless is?(:blk_filesystem)

        size = blk_devices.map(&:size).reduce(:+)
        used = detect_resize_info.min_size
        size - used
      rescue Storage::Exception
        return FREE_SPACE_FALLBACK
      end
    end
  end
end
