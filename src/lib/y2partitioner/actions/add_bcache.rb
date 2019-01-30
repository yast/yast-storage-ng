# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "y2partitioner/dialogs/bcache"
require "y2partitioner/device_graphs"
require "y2storage/bcache"

Yast.import "Popup"

module Y2Partitioner
  module Actions
    # Action following click on Add Bcache button.
    class AddBcache
      # Runs dialogs for adding bcache and also modify device graph if user confirm that dialog.
      def run
        dialog = Dialogs::Bcache.new(usable_blk_devices, usable_blk_devices + existing_caches)

        create_device(dialog) if dialog.run == :next
        :finish
      end

    private

      # Creates device according to user input to dialog.
      # @return [void]
      def create_device(dialog)
        backing = dialog.backing_device
        raise "Invalid result #{dialog.inspect}. Backing not found." unless backing

        caching = dialog.caching_device
        raise "Invalid result #{dialog.inspect}. Caching not found." unless caching

        bcache = backing.create_bcache(Y2Storage::Bcache.find_free_name(device_graph))

        set_options(bcache, dialog.options)

        if !caching.is?(:bcache_cset)
          caching.remove_descendants
          caching = caching.create_bcache_cset
        end

        bcache.attach_bcache_cset(caching)
      end

      def set_options(bcache, options)
        options.each_pair do |key, value|
          bcache.public_send(:"#{key}=", value)
        end
      end

      # Device graph on which action operates
      # @return [Y2Storage::Devicegraph]
      def device_graph
        DeviceGraphs.instance.current
      end

      # returns block devices that can be used for backing or caching device
      # @return [Array<Y2Storage::BlkDevice>]
      def usable_blk_devices
        device_graph.blk_devices.select do |dev|
          dev.component_of.empty? &&
            (dev.filesystem.nil? || dev.filesystem.mount_point.nil?) &&
            (!dev.respond_to?(:partitions) || dev.partitions.empty?) &&
            # do not allow nested bcaches, see doc/bcache.md
            ([dev] + dev.ancestors).none? { |a| a.is?(:bcache, :bcache_cset) }
        end
      end

      # returns existing caches for bcache.
      # @return [Array<Y2Storage::BcacheCset>]
      def existing_caches
        device_graph.bcache_csets
      end
    end
  end
end
