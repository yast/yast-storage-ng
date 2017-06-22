#!/usr/bin/env ruby
#
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

module Y2Storage
  module Planned
    # Specification for a Y2Storage::Partition object to be created during the
    # storage or AutoYaST proposals
    #
    # @see Device
    class Partition < Device
      include Planned::HasSize
      include Planned::CanBeFormatted
      include Planned::CanBeMounted
      include Planned::CanBeEncrypted

      # @return [::Storage::IdNum] id of the partition. If nil, the final id is
      #   expected to be inferred from the filesystem type.
      attr_accessor :partition_id

      # @return [String] device name of the disk in which the partition has to
      #   be located. If nil, the volume can be allocated in any disk.
      attr_accessor :disk

      # @return [DiskSize] maximum distance from the start of the disk in which
      #   the partition can start
      attr_accessor :max_start_offset

      # @return [Symbol] modifier to pass to ::Storage::Region#align when
      #   creating the volume. :keep_size to avoid size changes. nil to use
      #   default alignment.
      #   FIXME: this one is just guessing the final API of alignment
      attr_accessor :align

      # @return [Boolean] whether the boot flag should be set. Expected to be
      #   used only with ms-dos style partition tables. GPT has a similar legacy
      #   flag but is not needed in our grub2 setup.
      attr_accessor :bootable

      # @return [String]
      attr_accessor :lvm_volume_group_name

      # Constructor.
      #
      # @param mount_point [string] See {#mount_point}
      # @param filesystem_type [Filesystems::Type] See {#filesystem_type}
      def initialize(mount_point, filesystem_type = nil)
        initialize_has_size
        initialize_can_be_formatted
        initialize_can_be_mounted
        initialize_can_be_encrypted

        @mount_point = mount_point
        @filesystem_type = filesystem_type
      end

      # Checks whether the partition represents an LVM physical volume
      #
      # @return [Boolean]
      def lvm_pv?
        partition_id && partition_id.is?(:lvm)
      end

      def self.to_string_attrs
        [:mount_point, :reuse, :min_size, :max_size, :disk, :max_start_offset, :subvolumes]
      end

    protected

      def reuse_device!(device)
        super

        device.boot = true if bootable && device.respond_to?(:boot=)
      end
    end
  end
end
