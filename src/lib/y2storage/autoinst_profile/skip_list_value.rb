# encoding: utf-8
#
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

module Y2Storage
  module AutoinstProfile
    # This class reads information from disks to be used as values when
    # on skip lists. On one hand, the class implements logic to find out
    # the needed values; on the other hand, it can offer a backward compatibility
    # layer.
    #
    # NOTE: At this point, only a subset of them are implemented. Have a look at
    # `yast2 ayast_probe` to find out which values are supported in the old
    # libstorage.
    class SkipListValue
      # @return [Y2Storage::Disk] Disk
      attr_reader :disk
      private :disk

      # Constructor
      def initialize(disk)
        @disk = disk
      end

      # Size in kilobytes
      #
      # @return [Fixnum] Size
      def size_k
        disk.size.to_i
      end

      # Device full name
      #
      # @return [String] Full device name
      def device
        disk.name
      end

      # Device name
      #
      # @return [String] Last part of device name (for instance, sdb)
      def name
        disk.basename
      end
    end
  end
end
