# Copyright (c) [2020] SUSE LLC
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

require "yast/i18n"
require "y2storage/storage_class_wrapper"
require "y2storage/filesystems/base"

module Y2Storage
  module Filesystems
    # Class to represent a tmpfs.
    #
    # The Tmpfs object should always have MountPoint as child. So the Tmpfs
    # must be deleted whenever the MountPoint is removed.
    #
    # This is a wrapper for Storage::Tmpfs
    class Tmpfs < Base
      include Yast::I18n

      wrap_class Storage::Tmpfs

      # @!method self.create(devicegraph)
      #   @param devicegraph [Devicegraph]
      #   @return [Tmpfs]
      storage_class_forward :create, as: "Filesystems::Tmpfs"

      # @!method self.all(devicegraph)
      #   @param devicegraph [Devicegraph]
      #   @return [Array<Tmpfs>] all the tmp filesystems in the given devicegraph
      storage_class_forward :all, as: "Filesystems::Tmpfs"

      # Size of the filesystem, given by the corresponding mount option
      #
      # @return [DiskSize] zero if the size couldn't be determined
      def size
        DiskSize.parse(size_from_mount_options, legacy_units: true)
      rescue StandardError
        DiskSize.zero
      end

      # Name used to idenfity the device
      #
      # @return [String]
      def name
        # FIXME: wrapper classes should not provide strings to be presented in the UI. Use decorators.
        textdomain "storage"

        # TRANSLATORS: name used to identify a tmpfs filesystem, where %{fs_type} is replaced by the
        #   filesystem type (i.e., Tmpfs) and %{mount_path} is replaced by the tmpfs mount path
        #   (e.g., "/tmp").
        #
        #   Examples: "Tmpfs /tmp"
        format(_("%{type} %{mount_path}"), type: type.to_human_string, mount_path: mount_path)
      end

      protected

      # Name of the mount option used to determine the size of the tmpfs
      # @return [String]
      SIZE_OPT = "size".freeze
      private_constant :SIZE_OPT

      # @see Device#is?
      def types_for_is
        super << :tmpfs
      end

      # Mount options used to define the size of the temporary filesystem
      #
      # For a sane tmpfs, this should be an array with just one element. But it could be empty
      # if the size is not defined or could contain several entries if the "size=" argument is
      # specified more than once.
      #
      # @return [Array<String>]
      def size_mount_options
        return [] unless mount_point

        mount_point.mount_options.select { |opt| opt =~ /#{SIZE_OPT}=/i }
      end

      # String representation of the filesystem size, as specified in the mount options
      #
      # @return [String, nil] nil if no size is given in the mount options
      def size_from_mount_options
        option = size_mount_options.last
        return nil unless option

        option.split("=").last
      end
    end
  end
end
