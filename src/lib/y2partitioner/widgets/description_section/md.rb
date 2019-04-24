# encoding: utf-8

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

require "y2partitioner/widgets/description_section/base"
require "y2partitioner/widgets/blk_device_attributes"

module Y2Partitioner
  module Widgets
    module DescriptionSection
      # Description section with specific data about a MD device
      class Md < Base
        include BlkDeviceAttributes

        # Constructor
        #
        # @param device [Y2Storage::Md]
        def initialize(device)
          textdomain "storage"

          super
        end

      private

        ENTRIES = [
          { value: :raid_active },
          { value: :raid_type,       help: :raid_type },
          { value: :raid_chunk_size, help: :chunk_size },
          { value: :raid_parity,     help: :parity_algorithm },
          { value: :device_label,    help: :disk_label }
        ].freeze

        private_constant :ENTRIES

        # Required by mixin {BlkDeviceAttributes}
        alias_method :blk_device, :device

        # @see DescriptionSection::Base#title
        def title
          # TRANSLATORS: title for section about MD details
          _("RAID:")
        end

        # @see DescriptionSection::Base#entries
        def entries
          ENTRIES
        end

        # Information about MD RAID being (in)active
        #
        # @return [String]
        def raid_active
          # TRANSLATORS: RAID being active (assembled), where %s is replaced by
          # 'Yes' when the device is active or by 'No' otherwise
          format(_("Active: %s"), device.active? ? _("Yes") : _("No"))
        end

        # Information about MD RAID type
        #
        # @return [String]
        def raid_type
          # TRANSLATORS: RAID type information, where %s is replaced by a
          # raid type (e.g., RAID0)
          format(_("RAID Type: %s"), device.md_level.to_human_string)
        end

        # Information about the MD RAID chunk size according to mdadm(8):
        # chunk size "is only meaningful for RAID0, RAID4, RAID5, RAID6, and RAID10"
        #
        # @return [String]
        def raid_chunk_size
          # TRANSLATORS: chunk size information of the MD RAID, where %s is replaced by
          # a size (e.g., 8 KiB)
          chunk_size = device.chunk_size
          format(_("Chunk Size: %s"), chunk_size.zero? ? "" : chunk_size.to_human_string)
        end

        # Information about the MD RAID parity algorithm
        #
        # @return [String]
        def raid_parity
          # TRANSLATORS: parity algorithm information of a MD RAID, where %s is replaced by
          # the name of the parity strategy
          format(_("Parity Algorithm: %s"), device.md_parity.to_human_string)
        end
      end
    end
  end
end
