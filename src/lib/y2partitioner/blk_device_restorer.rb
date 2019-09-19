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

require "y2storage"
require "y2partitioner/device_graphs"

module Y2Partitioner
  # Class that makes possible to restore the filesystem or partition table
  # that was associated to a given block device in a previous point in time.
  #
  # This is used by the Partitioner to implement the "Do Not Format" option
  # (it restores the filesystem in the system devicegraph) and to implement
  # removing devices from the in-memory representation of an MD or LVM (it
  # restores the filesystem or the empty partition table that was associated
  # to the device when it was initially added to the MD or LVM).
  class BlkDeviceRestorer
    include Yast::Logger

    # Target device
    #
    # This device must be associated to the current devicegraph (see
    # {DeviceGraphs#current}). Its status and descendants will be updated with
    # every call to {#restore_from_checkpoint} or {#restore_from_system}.
    #
    # @return [Y2Storage::BlkDevice]
    attr_reader :device

    # Constructor
    #
    # @param device [Y2Storage::BlkDevice] see {#device}
    def initialize(device)
      @device = device
    end

    # Whether restoring the device to its status in the system devicegraph makes
    # sense.
    #
    # So far, that means the device existed in {DeviceGraphs#system} and it
    # was either empty or formatted, no matter whether it was encrypted or not.
    #
    # In other words, the current implementation return false if the device
    # was an LVM PV, part of an MD RAID or part of any similar complex setup.
    #
    # @return [Boolean]
    def can_restore_from_system?
      can_restore_device?(system_device)
    end

    # Restores the status of {#device} to its checkpoint, if such thing
    # makes sense.
    #
    # If no checkpoint has been defined, this is equivalent to
    # {#restore_from_system}. That is, if there is no checkpoint, it
    # restores from the system device or does nothing if the device is not in
    # the system devicegraph either.
    #
    # This restores the relevant attributes, the encryption device if any and
    # the filesystem if any, but not the mount point. Any possible previous
    # descendant of {#device} is deleted.
    #
    # @see #update_checkpoint
    def restore_from_checkpoint
      restore_device(checkpoint_device)
    end

    # Restores the status of {#device} to its equivalent status at
    # {DeviceGraphs#system}, if such thing makes sense.
    #
    # This restores the relevant attributes, the encryption device if any and
    # the filesystem if any, but not the mount point. Any possible previous
    # descendant of {#device} is deleted.
    #
    # @see #can_restore_from_system?
    def restore_from_system
      restore_device(system_device)
    end

    # Saves the current status of {#device} to make it possible to be restored
    # in the future, overwriting the previous checkpoint if any
    #
    # @see #restore_from_checkpoint
    def update_checkpoint
      DeviceGraphs.instance.update_checkpoint(device)
    end

    private

    # Whether it makes sense to restore a given device into {#device}
    #
    # @param dev [Y2Storage::BlkDevice, nil] source device
    # @return [Boolean]
    def can_restore_device?(dev)
      return false if dev.nil?
      return true if dev.descendants.empty?

      can_restore_descendants?(dev)
    end

    # @see #can_restore_device?
    #
    # @param dev [Y2Storage::BlkDevice, nil] source device
    # @return [Boolean]
    def can_restore_descendants?(dev)
      return true if dev.filesystem
      return true if dev.descendants.size == 1 && dev.encrypted?

      dev.respond_to?(:partition_table?) && dev.partition_table?
    end

    # Restores a given source device into {#device}
    #
    # @see #restore_from_system
    # @see #restore_from_checkpoint
    #
    # @param source [Y2Storage::BlkDevice, nil]
    def restore_device(source)
      return unless can_restore_device?(source)

      device.remove_descendants
      device.id = source.id if source.is?(:partition)

      restore_children(source) if source.has_children?
    end

    # @param source [Y2Storage::BlkDevice]
    def restore_children(source)
      if source.encrypted?
        restore_encryption_and_descendants(source)
      elsif source.respond_to?(:partition_table?) && source.partition_table?
        restore_partition_table(source)
      else
        restore_filesystem_and_descendants(source)
      end
    end

    # @param source [Y2Storage::BlkDevice]
    def restore_encryption_and_descendants(source)
      encryption = source.encryption

      copy_device(encryption)
      restore_filesystem_and_descendants(source) if source.filesystem
    end

    # @param source [Y2Storage::BlkDevice]
    def restore_filesystem_and_descendants(source)
      filesystem = source.filesystem

      copy_device(filesystem)
      copy_subvolumes(filesystem)
    end

    # @param source [Y2Storage::Partitionable]
    def restore_partition_table(source)
      ptable = source.partition_table

      copy_device(ptable)
    end

    # Recursively copy all the subvolumes of the source device to the current devicegraph, connecting
    # each of them to its corresponding parent
    #
    # @see Device#copy_to
    #
    # @param source [Y2Storage::Device]
    def copy_subvolumes(source)
      source.children.each do |child|
        next unless child.is?(:btrfs_subvolume)

        copy_device(child)
        copy_subvolumes(child)
      end
    end

    # Copy the source device to the current devicegraph
    #
    # @see Device#copy_to
    #
    # @raise [RuntimeError] if the device has more than one parent
    #
    # @param source [Y2Storage::Device]
    # @return [Y2Storage::Device] device copied to the current graph
    def copy_device(source)
      if source.to_storage_value.in_holders.size != 1
        log.error "Fails to copy: the device has more than one parent, that's unexpected: #{source.sid}"

        raise "Unexpected error copying the device #{source.sid}"
      end

      source.copy_to(current_graph)
    end

    # Equivalent to {#device} in the system devicegraph, if any
    #
    # @return [Y2Storage::BlkDevice, nil]
    def system_device
      DeviceGraphs.instance.system.find_device(device.sid)
    end

    # Equivalent to {#device} in its checkpoint devicegraph, if any
    #
    # @return [Y2Storage::BlkDevice, nil]
    def checkpoint_device
      checkpoint = DeviceGraphs.instance.checkpoint(device)
      dev = checkpoint.nil? ? nil : checkpoint.find_device(device.sid)
      dev || system_device
    end

    # @return [Y2Storage::Devicegraph]
    def current_graph
      DeviceGraphs.instance.current
    end
  end
end
