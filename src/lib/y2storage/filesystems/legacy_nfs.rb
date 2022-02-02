# Copyright (c) [2018-2020] SUSE LLC
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
require "y2storage/filesystems/nfs"
require "y2storage/filesystems/type"
require "y2storage/filesystems/nfs_options"

module Y2Storage
  module Filesystems
    # Class to represent an NFS mount, as defined in the old y2-storage.
    # This class is useful to connect code that uses objects of the new {Nfs}
    # class and code using the old hash-based format (the so-called TargetMap).
    # In particular to connect y2-storage-ng and y2-nfs-client.
    class LegacyNfs
      include Yast::Logger

      # Devicegraph to use by default in the subsequent operations
      # @return [Devicegraph]
      attr_accessor :default_devicegraph

      # Server name or IP address of the NFS share
      # @return [String]
      attr_accessor :server

      # Remote path of the NFS share
      # @return [String]
      attr_accessor :path

      # Previous server name or IP, used when the remote share is changed
      # (which strictly speaking means replacing the NFS mount with a new one)
      #
      # @see #server
      #
      # @return [String]
      attr_reader :old_server

      # Previous share path
      #
      # @see #old_server
      # @see #path
      #
      # @return [String]
      attr_reader :old_path

      # Local mount point path
      # @return [String]
      attr_accessor :mountpoint

      # Options field for fstab
      # @return [String]
      attr_accessor :fstopt

      # Filesystem type used in fstab
      # @return [Type] possible values are Type::NFS and Type::NFS4
      attr_reader :fs_type

      # Indicates whether the share should be mounted
      #
      # @return [Boolean]
      attr_writer :active

      # Indicates whether the share should be written in the fstab
      #
      # @return [Boolean]
      attr_writer :in_etc_fstab

      # Creates a new object from a hash with the legacy fields used in
      # TargetMap-based code.
      #
      # @return [LegacyNfs]
      def self.new_from_hash(legacy_hash)
        legacy = new
        legacy.initialize_from_hash(legacy_hash)
        legacy
      end

      # Creates a new object with an {Nfs} object as starting point.
      #
      # @return [LegacyNfs]
      def self.new_from_nfs(nfs)
        legacy = new
        legacy.initialize_from_nfs(nfs)
        legacy
      end

      # Constructor
      #
      # By default, the new share should be mounted and written to fstab
      def initialize
        @active = true
        @in_etc_fstab = true
        @fs_type = Type.find(:nfs)
      end

      # Whether the share should be mounted
      #
      # @return [Boolean]
      def active?
        !!@active
      end

      # Whether the share should be written to the fstab
      #
      # @return [Boolean]
      def in_etc_fstab?
        !!@in_etc_fstab
      end

      # Hash representation of the object, with the fields used in
      # TargetMap-based code (like y2-nfs-client).
      #
      # @return [Hash]
      def to_hash
        hash = {
          "device"  => share_string(server, path),
          "mount"   => mountpoint,
          "fstopt"  => fstopt,
          # Weird enough, yast2-nfs-client provides this value in the field
          # "vfstype" (see #initialize_from_hash), but it expects to get it in
          # the "used_fs" one. Asymmetry for the win!
          "used_fs" => fs_type.to_sym
        }
        hash["old_device"] = share_string(old_server, old_path) if share_changed?
        hash
      end

      # Creates an {Nfs} object, equivalent to this one, in the devicegraph
      #
      # @raise [ArgumentError] if no devicegraph is given and no default
      #   devicegraph has been previously defined
      #
      # @param devicegraph [Devicegraph, nil] if nil, the default devicegraph will be used
      # @return [Nfs] the new device
      def create_nfs_device(devicegraph = nil)
        graph = check_devicegraph_argument(devicegraph)

        nfs = Nfs.create(graph, server, path)

        return nfs if mountpoint.nil? || mountpoint.empty?

        nfs.mount_path = mountpoint
        nfs.mount_point.mount_options = nfs_options.options
        nfs.mount_point.active = active?
        nfs.mount_point.in_etc_fstab = in_etc_fstab?

        nfs
      end

      # Copies properties from a Nfs share
      #
      # Right now, this method only copies the required properties to keep the same mount point status
      # as the given Nfs share.
      #
      # @param nfs [Nfs]
      def configure_from(nfs)
        return if mountpoint.nil? || mountpoint.empty?

        return unless nfs.mount_point

        self.active = nfs.mount_point.active?
        self.in_etc_fstab = nfs.mount_point.in_etc_fstab?
      end

      # Updates the equivalent {Nfs} object in the given devicegraph
      #
      # @raise [ArgumentError] if no devicegraph is given and no default devicegraph has been previously
      #   defined.
      #
      # @param devicegraph [Devicegraph, nil] if nil, the default devicegraph will be used
      def update_nfs_device(devicegraph = nil)
        graph = check_devicegraph_argument(devicegraph)

        nfs = find_nfs_device(graph)

        if mountpoint.nil? || mountpoint.empty?
          nfs.remove_mount_point unless nfs.mount_point.nil?
        else
          nfs.mount_path = mountpoint
          nfs.mount_point.mount_type = fs_type
          nfs.mount_point.mount_options = nfs_options.options
        end
      end

      # Finds the equivalent {Nfs} object in the devicegraph
      #
      # It first tries to match the object by #old_server and #old_path and, if
      # that fails, by #server and #path.
      #
      # @raise [ArgumentError] if no devicegraph is given and no default
      #   devicegraph has been previously defined
      #
      # @param devicegraph [Devicegraph, nil] if nil, the default devicegraph
      #   will be used
      # @return [Nfs, nil] found device or nil if no device matches
      def find_nfs_device(devicegraph = nil)
        graph = check_devicegraph_argument(devicegraph)

        old = nil
        old = Nfs.find_by_server_and_path(graph, old_server, old_path) if share_changed?
        old || Nfs.find_by_server_and_path(graph, server, path)
      end

      # Whether this represents an NFS mount in which the remote share (server
      # and/or remote path) has changed
      #
      # In fact, changing the connection information implies replacing the
      # NFS mount with a new different one.
      #
      # @see #old_server
      # @see #old_path
      #
      # @return [Boolean]
      def share_changed?
        !old_server.nil?
      end

      # Whether the fstab entry uses old ways of configuring the NFS version that
      # do not longer work in the way they used to.
      #
      # @return [Boolean]
      def legacy_version?
        return true if fs_type == Y2Storage::Filesystems::Type::NFS4

        nfs_options.legacy?
      end

      def nfs_options
        NfsOptions.create_from_fstab(fstopt || "")
      end

      def version
        nfs_options.version
      end

      # @return [String]
      def inspect
        "<LegacyNfs attributes=#{to_hash}>"
      end

      # @see .new_from_hash
      def initialize_from_hash(attributes)
        @server, @path = split_share(attributes["device"])
        @mountpoint = attributes["mount"]
        @fstopt = attributes["fstopt"]
        vfstype = attributes.fetch("vfstype", :nfs)
        @fs_type = Type.find(vfstype)

        old_share = attributes["old_device"]
        return if old_share.nil? || old_share.empty?

        @old_server, @old_path = split_share(old_share)
      end

      # @see .new_from_nfs
      def initialize_from_nfs(nfs)
        @server     = nfs.server
        @path       = nfs.path
        @mountpoint = nfs.mount_path
        if nfs.mount_point
          mount_options = nfs.mount_point.mount_options
          @fs_type = nfs.mount_point.mount_type
        else
          mount_options = []
          @fs_type = Type::NFS
        end
        @fstopt = mount_options.empty? ? "defaults" : mount_options.join(",")
      end

      # String representing the remote NFS share, as specified in fstab
      #
      # @return [String]
      def share
        share_string(server, path)
      end

      protected

      # Breaks a string representing a share, in the format used in fstab, into
      # its two components (server and path)
      def split_share(share_string)
        share_string.split(":")
      end

      # Composes a string to represent a share, in the format used in fstab,
      # from its two components
      def share_string(svr, dir)
        "#{svr}:#{dir}"
      end

      # Ensures there is a devicegraph to work with, raising an exception
      # otherwise
      def check_devicegraph_argument(devicegraph)
        result = devicegraph || default_devicegraph
        return result if result

        raise ArgumentError, "No devicegraph (provided or default) for the operation"
      end
    end
  end
end
