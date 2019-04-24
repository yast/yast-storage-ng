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

module Y2Partitioner
  module Widgets
    module DescriptionSection
      # Description section with specific data about a Bcache device
      class Bcache < Base
        # Constructor
        #
        # @param device [Y2Storage::Bcache]
        def initialize(device)
          textdomain "storage"

          super
        end

      private

        ENTRIES = [
          { value: :bcache_backing_device, help: :backing_device },
          { value: :bcache_caching_uuid,   help: :caching_uuid },
          { value: :bcache_caching_device, help: :caching_device },
          { value: :bcache_cache_mode,     help: :cache_mod }
        ].freeze

        private_constant :ENTRIES

        # @see DescriptionSection::Base#title
        def title
          # TRANSLATORS: title for section about Bcache details
          _("Bcache Devices:")
        end

        # @see DescriptionSection::Base#entries
        def entries
          ENTRIES
        end

        # Enty data about the backing device
        #
        # @return [String]
        def bcache_backing_device
          format(_("Backing Device: %s"), backing_device)
        end

        # Enty data about the UUID of the caching set
        #
        # @return [String]
        def bcache_caching_uuid
          format(_("Caching UUID: %s"), uuid)
        end

        # Enty data about the caching device
        #
        # @return [String]
        def bcache_caching_device
          format(_("Caching Device: %s"), caching_device)
        end

        # Enty data about the cache mode
        #
        # @return [String]
        def bcache_cache_mode
          format(_("Cache Mode: %s"), cache_mode)
        end

        # UUID of the caching set
        #
        # @return [String]
        def uuid
          device.bcache_cset ? device.bcache_cset.uuid : ""
        end

        # Name of the devices used for caching
        #
        # @return [String]
        def caching_device
          device.bcache_cset ? device.bcache_cset.blk_devices.map(&:name).join(",") : ""
        end

        # Backing device name or an empty string if the device is a flash-only bcache
        #
        # @return [String]
        def backing_device
          return "" if device.flash_only?

          device.backing_device.name
        end

        # Cache mode or an empty string if the device is a flash-only bcache
        #
        # @return [String]
        def cache_mode
          return "" if device.flash_only?

          device.cache_mode.to_human_string
        end
      end
    end
  end
end
