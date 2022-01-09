# Copyright (c) [2020] SUSE LLC
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

require "y2partitioner/widgets/columns/disk_size"

module Y2Partitioner
  module Widgets
    module Columns
      # Widget for displaying the `Size` column
      class Size < DiskSize
        # Constructor
        def initialize
          super
          textdomain "storage"
        end

        # @see Columns::Base#title
        def title
          # TRANSLATORS: table header, size of block device e.g. "8.00 GiB"
          Right(_("Size"))
        end

        private

        # Returns the Y2Storage::DiskSize for the given device, if possible
        #
        # @param device [Y2Storage::Device, Y2Storage::SimpleEtcFstabEntry]
        #
        # @return [Y2Stoorage::DiskSize, nil] a disk size object when possible; nil otherwise
        def device_size(device)
          return nil unless device
          return fstab_device_size(device) if fstab_entry?(device)
          return bcache_cset_size(device) if device.is?(:bcache_cset)
          return subvolume_size(device) if device.is?(:btrfs_subvolume)

          device.respond_to?(:size) && device.size
        end

        # Returns the Y2Storage::DiskSize for a Y2Storage::BcacheCset, if possible
        #
        # @see #device_size
        #
        # @param bcache_cset [Y2Storage::BcacheCset]
        #
        # @return [Y2Storage::Disksize, nil]
        def bcache_cset_size(bcache_cset)
          device_size(bcache_cset.blk_devices.first)
        end

        # Returns the Y2Storage::DiskSize for a Y2Storage::SimpleEtcFstabEntry, if possible
        #
        # @see #device_size
        #
        # @param fstab_entry [Y2Storage::SimpleEtcFstabEntry]
        #
        # @return [Y2Storage::Disksize, nil]
        def fstab_device_size(fstab_entry)
          device = fstab_entry.device(system_graph)

          device_size(device)
        end

        # Returns the Y2Storage::DiskSize for a Y2Storage::BtrfsSubvolume, if possible
        #
        # Subvolumes don't have sizes in the strict sense. But if quotas are enabled for
        # the file system, this returns the referenced limit of the subvolume, if any.
        #
        # @see #device_size
        #
        # @param subvolume [Y2Storage::BtrfsSubvolume]
        # @return [Y2Storage::Disksize, nil]
        def subvolume_size(subvolume)
          return nil if subvolume.referenced_limit.unlimited?

          subvolume.referenced_limit
        end
      end
    end
  end
end
