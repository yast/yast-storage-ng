# Copyright (c) [2019] SUSE LLC
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
require "y2storage/planned/device"
require "y2storage/planned/mixins"
require "y2storage/match_volume_spec"
require "y2storage/filesystems/type"

module Y2Storage
  module Planned
    # Specification for a Y2Storage::Filesystems::Nfs object to be created during the
    # AutoYaST proposal
    #
    # @see Device
    class Nfs < Device
      include Planned::CanBeMounted
      include MatchVolumeSpec

      # @return [String] server name
      attr_accessor :server

      # @return [String] path to shared directory
      attr_accessor :path

      # Constructor
      #
      # @param server [String]
      # @param path [String]
      def initialize(server = "", path = "")
        super()

        initialize_can_be_mounted

        @server = server
        @path = path
      end

      protected

      # Values for volume specification matching
      #
      # @see MatchVolumeSpec
      def volume_match_values
        {
          mount_point:,
          size:         nil,
          fs_type:      Filesystems::Type::NFS,
          partition_id: nil
        }
      end
    end
  end
end
