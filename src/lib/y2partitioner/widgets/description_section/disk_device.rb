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
      # Description section with specific data about a disk device
      class DiskDevice < Base
        include BlkDeviceAttributes

        # Constructor
        #
        # The given device must be a disk device, i.e.: device.is?(:disk_device) == true
        #
        # @param device [Y2Storage::BlkDevice]
        def initialize(device)
          textdomain "storage"

          super
        end

      private

        ENTRIES = [
          { value: :device_vendor,      help: :vendor },
          { value: :device_model,       help: :model },
          { value: :device_bus,         help: :bus },
          { value: :device_sectors,     help: :sectors },
          { value: :device_sector_size, help: :sector_size },
          { value: :device_label,       help: :disk_label }
        ].freeze

        private_constant :ENTRIES

        # Required by mixin {BlkDeviceAttributes}
        alias_method :blk_device, :device

        # @see DescriptionSection::Base#title
        def title
          # TRANSLATORS: title for section about disk device details
          _("Hard Disk:")
        end

        # @see DescriptionSection::Base#entries
        def entries
          ENTRIES
        end
      end
    end
  end
end
