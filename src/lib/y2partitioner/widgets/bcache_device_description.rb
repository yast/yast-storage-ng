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

require "y2partitioner/widgets/disk_device_description"

module Y2Partitioner
  module Widgets
    # Richtext filled with the description of a bcache devices
    #
    # The bcache device is given during initialization (see {BlkDeviceDescription}).
    class BcacheDeviceDescription < DiskDeviceDescription
      def initialize(*args)
        super
        textdomain "storage"
      end

      # @see #disk_device_description
      # @see #bcache_description
      #
      # @return [String]
      def device_description
        super + bcache_description
      end

      def bcache_description
        output = Yast::HTML.Heading(_("Bcache Devices:"))
        output << Yast::HTML.List([
          format(_("Backing device: %s"), device.blk_device.name.to_s),
          format(_("Caching UUID: %s"), device.bcache_cset ? device.bcache_cset.uuid : ""),
          format(_("Caching device: %s"),
            device.bcache_cset ? device.bcache_cset.blk_devices.map(&:name).join(",") : ""
          )
        ])
      end
    end
  end
end
