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

require "yast"
require "y2storage/autoinst_profile/section_with_attributes"

module Y2Storage
  module AutoinstProfile
    # Thin object oriented layer on top of a <partition> section of the
    # AutoYaST profile.
    #
    # More information can be found in the 'Partitioning' section ('Partition
    # Configuration' subsection) of the AutoYaST documentation:
    # https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#ay.partition_configuration
    # Check that document for details about the semantic of every attribute.
    class PartitionSection < SectionWithAttributes
      def self.attributes
        [
          { name: :create },
          { name: :filesystem },
          { name: :format },
          { name: :label },
          { name: :uuid },
          { name: :lv_name },
          { name: :lvm_group },
          { name: :mount },
          { name: :mountby },
          { name: :partition_id },
          { name: :partition_nr },
          { name: :partition_type },
          { name: :subvolumes },
          { name: :size },
          { name: :crypt_fs },
          { name: :loop_fs },
          { name: :crypt_key }
        ]
      end

      define_attr_accessors

      # @!attribute create
      #   @return [Boolean] whether the partition must be created or exists

      # @!attribute crypt_fs
      #   @return [Boolean] whether the partition must be encrypted

      # @!attribute crypt_key
      #   @return [String] encryption key

      # @!attribute filesystem
      #   @return [Symbol] file system type to use in the partition, it also
      #     influences other fields
      #   @see #type_for_filesystem
      #   @see #id_for_partition

      # @!attribute partition_id
      #   @return [Fixnum] partition id. See #id_for_partition

      # @!attribute format
      #   @return [Boolean] whether the partition should be formatted

      # @!attribute label
      #   @return [String] label of the filesystem

      # @!attribute uuid
      #   @return [String] UUID of the partition

      # @!attribute lv_name
      #   @return [String] name of the LVM logical volume

      # @!attribute mount
      #   @return [String] mount point for the partition

      # @!attribute mountby
      #   @return [Symbol] :device, :label, :uuid, :path or :id

      # @!attribute partition_nr
      #   @return [Fixnum] the partition number of this partition

      # @!attribute partition_type
      #   @return [String] undocumented attribute that can only contain "primary"

      # @!attribute subvolumes
      #   @return [Array] list of subvolumes

      # @!attribute size
      #   @return [String] size of the partition in the flexible AutoYaST format

      # @!attribute loop_fs
      #   @return [Boolean] undocumented attribute

      def initialize
        @subvolumes = []
      end

      # Filesystem type to be used for the real partition object, based on the
      # #filesystem value.
      #
      # @return [Filesystems::Type]
      def type_for_filesystem
        return nil unless filesystem
        Filesystems::Type.find(filesystem)
      end

      # Partition id to be used for the real partition object.
      #
      # This implements the AutoYaST documented logic. If #partition_id is
      # filled, the corresponding id is used. Otherwise SWAP or LINUX will be
      # used, depending on the value of #filesystem.
      #
      # @return [PartitionId]
      def id_for_partition
        return PartitionId.new_from_legacy(partition_id) if partition_id
        return PartitionId::SWAP if type_for_filesystem && type_for_filesystem.is?(:swap)
        PartitionId::LINUX
      end
    end
  end
end
