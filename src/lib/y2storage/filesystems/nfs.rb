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
require "y2storage/filesystems/base"

module Y2Storage
  module Filesystems
    # Class to represent a NFS mount.
    #
    # The class does not provide functions to change the server or path since
    # that would create a completely different filesystem.
    #
    # This a wrapper for Storage::Nfs
    class Nfs < Base
      wrap_class Storage::Nfs

      # @!method server
      #   @return [String]
      storage_forward :server

      # @!method path
      #   @return [String]
      storage_forward :path

      # @!method self.all(devicegraph)
      #   @param devicegraph [Devicegraph]
      #   @return [Array<Nfs>] all the NFS mounts in the given devicegraph
      storage_class_forward :all, as: "Filesystems::Nfs"

      # @!method self.find_by_server_and_path(devicegraph, server, path)
      #   @param devicegraph [Devicegraph]
      #   @param server [String]
      #   @param path [String]
      #   @return [Filesystems::Nfs] nil if there is no such NFS mount
      storage_class_forward :find_by_server_and_path, as: "Filesystems::Nfs"

      # @return [Boolean]
      def in_network?
        return true
      end

    protected

      def types_for_is
        super << :nfs
      end
    end
  end
end
