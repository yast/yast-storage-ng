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
      #   The filesystem has to exists on the disk (i.e., in the probed
      #   devicegraph), this will mount it and then call the "df" command.
      #   Since both operations are expensive, caching this value is advised if
      #   it is needed repeatedly.
      #
      #   @raise [Storage::Exception] if the filesystem couldn't be mounted
      #     (e.g. it does not exist in the system or mount command failed)
      #
      #   @return [SpaceInfo]
      storage_forward :detect_space_info, as: "SpaceInfo"

      # Smart detection of free space
      #
      # It tries to use detect_space_info and caches it. But if it fails, it tries
      # to compute it from resize_info. If it fails again or filesystem is
      # not a block filesystem, then it returns zero size.
      #
      # @return [DiskSize]
      def free_space
        return @free_space if @free_space

        begin
          @free_space = detect_space_info.free
        rescue Storage::Exception
          # ok, we do not know it, so we try to detect ourself
          @free_space = compute_free_space
        end
      end

      # @return [Boolean]
      def in_network?
        false
      end

      # Whether the current filesystem matches with a given fstab spec
      #
      # Most formats supported in the first column of /etc/fstab are recognized.
      # E.g. the string can be a kernel name, an udev name, an NFS specification
      # or a string starting with "UUID=" or "LABEL=".
      #
      # This method doesn't match by PARTUUID or PARTLABEL.
      #
      # Take into account that libstorage-ng discards during probing all the
      # udev names not considered reliable or stable enough. This method only
      # checks by the udev names recognized by libstorage-ng (not discarded).
      #
      # @param spec [String] content of the first column of an /etc/fstab entry
      # @return [Boolean]
      def match_fstab_spec?(spec)
        log.warn "Method of the base abstract class used to check #{spec}"
        false
      end

      protected

      def types_for_is
        super << :filesystem
      end

      FREE_SPACE_FALLBACK = DiskSize.zero
      def compute_free_space
        # e.g. nfs where blk_devices cannot be queried
        return FREE_SPACE_FALLBACK unless respond_to?(:blk_devices)

        size = blk_devices.map(&:size).reduce(:+)
        used = resize_info.min_size
        size - used
      rescue Storage::Exception
        # it is questionable if this is correct behavior when resize_info failed,
        # but there is high chance we can't use it with libstorage, so better act like zero device.
        FREE_SPACE_FALLBACK
      end
    end
  end
end
