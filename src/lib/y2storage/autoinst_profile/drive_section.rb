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
require "y2storage/autoinst_profile/skip_list_section"
require "y2storage/autoinst_profile/partition_section"

Yast.import "Arch"

module Y2Storage
  module AutoinstProfile
    # Thin object oriented layer on top of a <drive> section of the
    # AutoYaST profile.
    #
    # More information can be found in the 'Partitioning' section of the AutoYaST documentation:
    # https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Partitioning
    # Check that document for details about the semantic of every attribute.
    class DriveSection < SectionWithAttributes
      def self.attributes
        [
          { name: :device },
          { name: :disklabel },
          { name: :enable_snapshots },
          { name: :imsmdriver },
          { name: :initialize_attr, xml_name: :initialize },
          { name: :keep_unknown_lv },
          { name: :lvm2 },
          { name: :is_lvm_vg },
          { name: :partitions },
          { name: :pesize },
          { name: :type },
          { name: :use },
          { name: :skip_list }
        ]
      end

      define_attr_accessors

      # @!attribute device
      #   @return [String] device name

      # @!attribute disklabel
      #   @return [String] partition table type

      # @!attribute enable_snapshots
      #   @return [Boolean] undocumented attribute

      # @!attribute imsmdriver
      #   @return [Symbol] undocumented attribute

      # @!attribute initialize_attr
      #   @return [Boolean] value of the 'initialize' attribute in the profile
      #     (reserved name in Ruby). Whether the partition table must be wiped
      #     out at the beginning of the AutoYaST process.

      # @!attribute keep_unknown_lv
      #   @return [Boolean] whether the existing logical volumes should be
      #   kept. Only makes sense if #type is :CT_LVM and there is a volume group
      #   to reuse.

      # @!attribute lvm2
      #   @return [Boolean] undocumented attribute

      # @!attribute is_lvm_vg
      #   @return [Boolean] undocumented attribute

      # @!attribute partitions
      #   @return [Array<PartitionSection>] a list of <partition> entries

      # @!attribute pesize
      #   @return [String] size of the LVM PE

      # @!attribute type
      #   @return [Symbol] :CT_DISK or :CT_LVM

      # @!attribute use
      #   @return [String] strategy AutoYaST will use to partition the disk

      # @!attribute skip_list
      #   @return [Array<SkipListSection] collection of <skip_list> entries

      def initialize
        @partitions = []
        @skip_list = SkipListSection.new([])
      end

      # Method used by {.new_from_hashes} to populate the attributes.
      #
      # It only enforces default values for #type (:CT_DISK) and #use ("all")
      # since the {AutoinstProposal} algorithm relies on them.
      #
      # @param hash [Hash] see {.new_from_hashes}
      def init_from_hashes(hash)
        super
        @type ||= :CT_DISK
        @use  ||= "all"
        @partitions = partitions_from_hash(hash)
        @skip_list = SkipListSection.new_from_hashes(hash.fetch("skip_list", []))
      end

    protected

      def partitions_from_hash(hash)
        return [] unless hash["partitions"]
        hash["partitions"].map { |part| PartitionSection.new_from_hashes(part) }
      end
    end
  end
end
