# encoding: utf-8

# Copyright (c) [2015-2017] SUSE LLC
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

module Y2Storage
  module Planned
    # Specification for a Y2Storage::StrayBlkDevice object to be processed
    # during the AutoYaST proposals
    #
    # FIXME: When a disk device is used as PV (indicated as partition with number 0
    # in the autoyast profile), a Stray Block Device is planned for it. Think about
    # a better solution (maybe by creating a Planned::PV ?).
    #
    # @see Device
    class StrayBlkDevice < Device
      include Planned::CanBeFormatted
      include Planned::CanBeMounted
      include Planned::CanBeEncrypted
      include Planned::CanBePv
      include MatchVolumeSpec

      # Constructor.
      def initialize
        super
        initialize_can_be_formatted
        initialize_can_be_mounted
        initialize_can_be_encrypted
        initialize_can_be_pv
      end

      # @see Device.to_string_attrs
      def self.to_string_attrs
        [
          :mount_point, :reuse_name, :reuse_sid, :subvolumes
        ]
      end

    protected

      # Values for volume specification matching
      #
      # @see MatchVolumeSpec
      def volume_match_values
        {
          mount_point: mount_point,
          fs_type:     filesystem_type
        }
      end
    end
  end
end
