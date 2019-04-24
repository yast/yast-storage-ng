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
      # Description section with specific data about a block device
      class BlkDevice < Base
        include BlkDeviceAttributes

        # Constructor
        #
        # @param device [Yy2Storage::BlkDevice]
        def initialize(device)
          textdomain "storage"

          super
        end

      private

        ENTRIES = [
          { value: :device_name,         help: :device },
          { value: :device_size,         help: :size },
          { value: :device_encrypted,    help: :encrypted },
          { value: :device_udev_by_path, help: :udev_path },
          { value: :device_udev_by_id,   help: :udev_id }
        ].freeze

        private_constant :ENTRIES

        # Required by mixin {BlkDeviceAttributes}
        alias_method :blk_device, :device

        # @see DescriptionSection::Base#title
        def title
          # TRANSLATORS: title for section about block device details
          _("Device:")
        end

        # @see DescriptionSection::Base#entries
        def entries
          ENTRIES
        end

        # Enty data about the udev by_path values
        #
        # Note that this method is already provided by the mixin {BlkDeviceAttributes},
        # but here the values are joined.
        #
        # @return [String]
        def device_udev_by_path
          super.join(Yast::HTML.Newline)
        end

        # Enty data about the udev by_id values
        #
        # Note that this method is already provided by the mixin {BlkDeviceAttributes},
        # but here the values are joined.
        #
        # @return [String]
        def device_udev_by_id
          super.join(Yast::HTML.Newline)
        end
      end
    end
  end
end
