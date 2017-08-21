# encoding: utf-8

# Copyright (c) [2012-2016] Novell, Inc.
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
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

require "yast"
require "y2storage/planned/device"
require "y2storage/planned/mixins"

module Y2Storage
  module Planned
    # Specification for a Y2Storage::BtrfsSubvolume object to be created during
    # the storage or AutoYaST proposals
    #
    # @see Device
    class BtrfsSubvolume < Device
      include Planned::CanBeMounted

      # @return [String] path of the subvolume
      attr_accessor :path

      # @return [Boolean] whether CopyOnWrite should be enabled
      attr_accessor :copy_on_write

      def initialize
        initialize_can_be_mounted
      end

      def self.to_string_attrs
        [:mount_point, :path, :copy_on_write]
      end

      # Create the subvolume as child of 'parent_subvol'.
      #
      # @param parent_subvol [Y2Storage::BtrfsSubvol]
      # @param default_subvol [String] "@" or ""
      #
      # @return [Y2Storage::BtrfsSubvol]
      def create_subvol(parent_subvol, default_subvol)
        name = default_subvol.empty? ? path : "#{default_subvol}/#{path}"
        subvol = parent_subvol.create_btrfs_subvolume(name)
        subvol.nocow = !copy_on_write
        subvol.mountpoint = mount_point
        # Proposed subvolumes can be automatically deleted when they are shadowed
        subvol.can_be_auto_deleted = true
        subvol
      end
    end
  end
end
