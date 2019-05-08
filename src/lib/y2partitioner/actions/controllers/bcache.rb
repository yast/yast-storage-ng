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

require "yast"
require "y2storage/bcache"
require "y2partitioner/device_graphs"
require "y2partitioner/blk_device_restorer"
require "y2partitioner/actions/controllers/available_devices"

module Y2Partitioner
  module Actions
    module Controllers
      # This class is used by different Bcache actions (see, {Actions::AddBcache},
      # {Actions::EditBcache} and {Actions::DeleteBcache}).
      class Bcache
        include AvailableDevices

        # @return [Y2Storage::Bcache]
        attr_reader :bcache

        # Constructor
        #
        # @param bcache [Y2Storage::Bcache, nil] nil if a new bcache is being created.
        def initialize(bcache = nil)
          @bcache = bcache
        end

        # Suitable devices to be used as backing device
        #
        # When the bcache is being edited, only its own backing device is returned.
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def suitable_backing_devices
          return [bcache.backing_device] if bcache

          available_devices
        end

        # Suitable devices to be used for caching
        #
        # @return [Array<Y2Storage::BcacheCset, Y2Storage::BlkDevice>]
        def suitable_caching_devices
          bcache_csets + available_devices
        end

        # Creates a bcache device
        #
        # @param backing_device [Y2Storage::BlkDevice]
        # @param caching_device [Y2Storage::BlkDevice, Y2Storage::BcacheCset, nil]
        # @param options [Hash<Symbol, Object>]
        def create_bcache(backing_device, caching_device, options)
          raise "A bcache cannot be created without a backing device." unless backing_device

          BlkDeviceRestorer.new(backing_device).update_checkpoint

          backing_device.remove_descendants if remove_backing_device_content?(backing_device)

          @bcache = backing_device.create_bcache(Y2Storage::Bcache.find_free_name(current_graph))

          apply_options(options)
          attach(caching_device) if caching_device
        end

        # Updates the bcache device
        #
        # @param caching_device [Y2Storage::BlkDevice, Y2Storage::BcacheCset, nil]
        # @param options [Hash<Symbol, Object>]
        def update_bcache(caching_device, options)
          apply_options(options)

          return if caching_device == bcache.bcache_cset

          detach if bcache.bcache_cset

          attach(caching_device) if caching_device
        end

        # Deletes the bcache device
        def delete_bcache
          backing_device = bcache.backing_device
          caching_device = nil

          if bcache.bcache_cset && bcache.bcache_cset.bcaches.size == 1
            caching_device = bcache.bcache_cset.blk_devices.first
          end

          current_graph.remove_bcache(bcache)

          # Tries to restore the previous status of the caching and backing devices
          # (e.g., its filesystem is restored back).
          BlkDeviceRestorer.new(caching_device).restore_from_checkpoint if caching_device
          BlkDeviceRestorer.new(backing_device).restore_from_checkpoint
        end

        # Whether the bcache already exists on disk
        #
        # @return [Boolean]
        def committed_bcache?
          !committed_bcache.nil?
        end

        # Whether the bcache on disk already had a caching set
        #
        # @return [Boolean]
        def committed_bcache_cset?
          !committed_bcache_cset.nil?
        end

        # Whether the bcache on disk already had a caching set, and this caching set was not
        # used by another bcache.
        #
        # @return [Boolean]
        def single_committed_bcache_cset?
          return false unless committed_bcache_cset?

          committed_bcache_cset.bcaches.size == 1
        end

      private

        # Block devices that can be used as backing or caching device
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def available_devices
          super(current_graph) { |d| valid_device?(d) }
        end

        # Whether the device can be used as backing or caching device
        #
        # @param device [Y2Storage::BlkDevice]
        # @return [Boolean]
        def valid_device?(device)
          valid_device_type?(device) && !device_belong_to_bcache?(device)
        end

        # Whether the device has a proper type to be used as backing or caching device
        #
        # @param device [Y2Storage::BlkDevice]
        # @return [Boolean]
        def valid_device_type?(device)
          device.is?(:disk, :multipath, :dasd, :stray, :partition, :lvm_lv)
        end

        # Whether the device is part of a bcache device
        #
        # @param device [Y2Storage::BlkDevice]
        # @return [Boolean]
        def device_belong_to_bcache?(device)
          # do not allow nested bcaches, see doc/bcache.md
          device.ancestors.any? { |a| a.is?(:bcache, :bcache_cset) }
        end

        # Currently existing caching sets
        #
        # @return [Array<Y2Storage::BcacheCset>]
        def bcache_csets
          current_graph.bcache_csets
        end

        # Applies options to the bcache device
        #
        # Right now, only the cache mode can be permanently modified.
        #
        # @param options [Hash<Symbol, Object>]
        def apply_options(options)
          options.each_pair do |key, value|
            bcache.public_send(:"#{key}=", value)
          end
        end

        # Attaches the selected caching to the bcache
        #
        # @param caching_device [Y2Storage::BcacheCset, Y2Storage::BlkDevice]
        def attach(caching_device)
          bcache_cset = create_bcache_cset(caching_device)

          bcache.add_bcache_cset(bcache_cset)
        end

        # Detaches the caching set from the bcache device
        def detach
          bcache_cset = bcache.bcache_cset

          bcache.remove_bcache_cset

          remove_bcache_cset(bcache_cset) if remove_bcache_cset?(bcache_cset)
        end

        # Creates a new caching set if the given caching device is not a caching set yet
        #
        # @param caching_device [Y2Storage::BlkDevice, Y2Storage::BcacheCset]
        def create_bcache_cset(caching_device)
          return caching_device if caching_device.is?(:bcache_cset)

          # The descendants of the caching device should be restored in case that
          # this caching set is finally removed and not used at all.
          BlkDeviceRestorer.new(caching_device).update_checkpoint

          caching_device.remove_descendants
          caching_device.create_bcache_cset
        end

        # Whether the caching set should be removed
        #
        # @param bcache_cset [Y2Storage::BcacheCset]
        def remove_bcache_cset?(bcache_cset)
          bcache_cset.bcaches.none?
        end

        # Removes the caching set
        #
        # Previous state of the caching device is retored.
        #
        # @param bcache_cset [Y2Storage::BcacheCset]
        def remove_bcache_cset(bcache_cset)
          caching_device = bcache_cset.blk_devices.first

          current_graph.remove_bcache_cset(bcache_cset)

          BlkDeviceRestorer.new(caching_device).restore_from_checkpoint
        end

        # Whether the content of the backing device should be removed
        #
        # The content of the backing device should be removed when the backing device
        # already contains something on the disk (e.g., a filesystem).
        #
        # @return [Boolean]
        def remove_backing_device_content?(backing_device)
          return false unless committed_device?(backing_device)

          backing_device.descendants.any? { |d| committed_device?(d) }
        end

        # Bcache existing on disk
        #
        # @return [Y2Storage::Bcache, nil] nil if the bcache is being created or
        #   does not exist on the disk yet.
        def committed_bcache
          return nil unless bcache

          committed_device(bcache)
        end

        # Caching set of the bcache existing on disk
        #
        # @return [Y2Storage::BcacheCset, nil] nil if the bcache does not exist
        #   on disk or it has no caching set.
        def committed_bcache_cset
          return nil unless committed_bcache?

          committed_bcache.bcache_cset
        end

        # Whether the device already exists on disk
        #
        # @param device [Y2Storage::Device]
        # @return [Boolean]
        def committed_device?(device)
          !committed_device(device).nil?
        end

        # System version of the given device
        #
        # @param device [Y2Storage::Device]
        # @return [Y2Storage::Device, nil] nil if the device does not exist on disk.
        def committed_device(device)
          system_graph.find_device(device.sid)
        end

        # Current devicegraph in which the action operates on
        #
        # @return [Y2Storage::Devicegraph]
        def current_graph
          DeviceGraphs.instance.current
        end

        # Devicegraph representing the system status
        #
        # @return [Y2Storage::Devicegraph]
        def system_graph
          DeviceGraphs.instance.system
        end
      end
    end
  end
end
