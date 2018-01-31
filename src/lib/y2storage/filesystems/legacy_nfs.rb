# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
      attr_reader :server

      # Remote path of the NFS share
      # @return [String]
      attr_reader :path

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
      attr_reader :mountpoint

      # Options field for fstab
      # @return [String]
      attr_reader :fstopt

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

      # Hash representation of the object, with the fields used in
      # TargetMap-based code (like y2-nfs-client).
      #
      # @return [Hash]
      def to_hash
        hash = {
          "device"  => share_string(server, path),
          "mount"   => mountpoint,
          "fstopt"  => fstopt,
          # TODO: libstorage-ng does not distinguish different NFS versions, so
          # for the time being, always use :nfs here
          "used_fs" => :nfs
        }
        hash["old_device"] = share_string(old_server, old_path) if share_changed?
        hash
      end

      # Creates an {Nfs} object, equivalent to this one, in the devicegraph
      #
      # @raise [ArgumentError] if no devicegraph is given and no default
      #   devicegraph has been previously defined
      #
      # @param devicegraph [Devicegraph, nil] if nil, the default devicegraph
      #   will be used
      # @return [Nfs] the new device
      def create_nfs_device(devicegraph = nil)
        graph = check_devicegraph_argument(devicegraph)

        # TODO: libstorage-ng does not distinguish different NFS versions
        dev = Nfs.create(graph, server, path)
        dev.mountpoint = mountpoint
        dev.fstab_options = fstopt == "defaults" ? [] : fstopt.split(/[\s,]+/)
        dev
      end

      # Updates the equivalent {Nfs} object in the devicegraph
      #
      # @raise [ArgumentError] if no devicegraph is given and no default
      #   devicegraph has been previously defined
      #
      # @param devicegraph [Devicegraph, nil] if nil, the default devicegraph
      #   will be used
      def update_nfs_device(devicegraph = nil)
        graph = check_devicegraph_argument(devicegraph)

        nfs = find_nfs_device(graph)
        nfs.mountpoint = mountpoint
        nfs.fstab_options = fstopt.split(/[\s,]+/)
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
        if share_changed?
          old = Nfs.find_by_server_and_path(graph, old_server, old_path)
        end
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

      # @return [String]
      def inspect
        "<LegacyNfs attributes=#{to_hash}>"
      end

      # @see .new_from_hash
      def initialize_from_hash(attributes)
        @server, @path = split_share(attributes["device"])
        @mountpoint = attributes["mount"]
        @fstopt = attributes["fstopt"]

        old_share = attributes["old_device"]
        return if old_share.nil? || old_share.empty?
        @old_server, @old_path = split_share(old_share)
      end

      # @see .new_from_nfs
      def initialize_from_nfs(nfs)
        @server     = nfs.server
        @path       = nfs.path
        @mountpoint = nfs.mountpoint
        @fstopt     = nfs.fstab_options.empty? ? "defaults" : nfs.fstab_options.join(",")
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
