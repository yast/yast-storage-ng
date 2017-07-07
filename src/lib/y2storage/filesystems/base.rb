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

      # @!method self.in_network?
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
