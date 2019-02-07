# encoding: utf-8

# Copyright (c) [2018-2019] SUSE LLC
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

module Y2Partitioner
  module Actions
    # Action for adding a bcache device
    class AddBcache
      # Runs dialogs for adding a bcache and also modify device graph if user confirm
      # the dialog.
      #
      # @return [Symbol] :finish
      def run
        dialog = Dialogs::Bcache.new(suitable_backing_devices, suitable_caching_devices)

        create_device(dialog) if dialog.run == :next

        :finish
      end

    private

      # Creates a bcache device according to the user input
      #
      # @param dialog [Dialogs::Bcache]
      def create_device(dialog)
        backing = dialog.backing_device

        raise "Invalid result #{dialog.inspect}. Backing not found." unless backing

        bcache = backing.create_bcache(Y2Storage::Bcache.find_free_name(device_graph))

        apply_options(bcache, dialog.options)

        attach(bcache, dialog.caching_device) if dialog.caching_device
      end

      # Applies options to the bcache device
      #
      # Right now, the dialog only allows to indicate the cache mode.
      #
      # @param bcache [Y2Storage::Bcache]
      # @param options [Hash<Symbol, Object>]
      def apply_options(bcache, options)
        options.each_pair do |key, value|
          bcache.public_send(:"#{key}=", value)
        end
      end

      # Attaches the selected caching to the bcache
      #
      # @param bcache [Y2Storage::Bcache]
      # @param caching [Y2Storage::BcacheCset, Y2Storage::BlkDevice, nil]
      def attach(bcache, caching)
        return if caching.nil?

        if !caching.is?(:bcache_cset)
          caching.remove_descendants
          caching = caching.create_bcache_cset
        end

        bcache.attach_bcache_cset(caching)
      end

      # Device graph in which the action operates on
      #
      # @return [Y2Storage::Devicegraph]
      def device_graph
        DeviceGraphs.instance.current
      end

      # Suitable devices to be used as backing device
      #
      # @return [Array<Y2Storage::BlkDevice>]
      def suitable_backing_devices
        usable_blk_devices
      end

      # Suitable devices to be used for caching
      #
      # @return [Array<Y2Storage::BcacheCset, Y2Storage::BlkDevice>]
      def suitable_caching_devices
        existing_caches + usable_blk_devices
      end

      # Block devices that can be used as backing or caching device
      #
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

      # Currently existing caching sets
      #
      # @return [Array<Y2Storage::BcacheCset>]
      def existing_caches
        device_graph.bcache_csets
      end
    end
  end
end
