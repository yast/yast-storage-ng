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

require "y2storage"

module Y2Partitioner
  # A singleton class that helps to work with a copy of the system
  # {Y2Storage::Devicegraph}.
  # FIXME: the spelling is different
  class DeviceGraphs
    class << self
      def instance
        create_instance(nil, nil) unless @instance
        @instance
      end

      # Creates the singleton instance with customized devicegraphs. To
      # be used during the initialization of the partitioner.
      def create_instance(system, initial)
        @instance = new(system: system, initial: initial)
      end

      # Make sure only .instance and .create_instance can be used to
      # create objects
      private :new, :allocate
    end

    # Devicegraph representing the system
    #
    # @return [Y2Storage::Devicegraph]
    attr_reader :system

    # Devicegraph representing the initial state
    #
    # @note The initial state is useful to known if something has been modified.
    #
    # @return [Y2Storage::Devicegraph]
    attr_reader :initial

    # Working Devicegraph, to be modified during the partitioner execution
    #
    # @return [Y2Storage::Devicegraph]
    attr_accessor :current

    # Disk analyzer for the system graph
    #
    # @return [Y2Storage::DiskAnalyzer]
    attr_reader :disk_analyzer

    def initialize(system: nil, initial: nil)
      @system = system || storage_manager.probed
      @initial = initial || storage_manager.staging
      @current = @initial.dup
      @checkpoints = {}
    end

    # Disk analyzer for the system devicegraph
    #
    # @note In case system and probed devicegraphs are equal, the probed disk analyzer
    #   is used, even when both devicegraphs are not exactly the same object. Otherwise,
    #   a new disk analyzer is created.
    #
    # @return [Y2Storage::DiskAnalyzer]
    def disk_analyzer
      return @disk_analyzer if @disk_analyzer

      @disk_analyzer =
        if system == storage_manager.probed
          storage_manager.probed_disk_analyzer
        else
          Y2Storage::DiskAnalyzer.new(system)
        end
    end

    # Makes a copy of the `current` devicegraph and runs a block with the copy.
    #
    # If the block fails or raises an exception, then the original devicegraph is restored.
    # Otherwise, the modified copy of the devicegraph becomes the `current` devicegraph.
    #
    # Finally, if an exception is not raised, then the result of the block call is returned.
    #
    # @note It is important to keep the original devicegraph when the transaction is aborted.
    #   In that cases, the interface could not be refreshed, and it continues using the original
    #   devicegraph.
    #
    # @yieldreturn [Boolean]
    # @return What the block returned
    def transaction(&block)
      initial_graph = current
      self.current = initial_graph.dup
      begin
        res = block.call

        self.current = initial_graph if !res
      rescue
        self.current = initial_graph
        raise
      end

      res
    end

    # Stores a snapshot of the current devicegraph associated to the given
    # device.
    #
    # Used by {BlkDeviceRestorer} to remember the current status of the device
    # so it can be restored later.
    #
    # @see BlkDeviceRestorer#update_checkpoint
    #
    # @param device [Y2Storage::Device] index, i.e. device to which the
    #   checkpoint is associated
    def update_checkpoint(device)
      @checkpoints[device.sid] = current.dup
    end

    # Checkpoint associated to the given device
    #
    # @see #update_checkpoint
    #
    # @param device [Y2Storage::Device]
    # @return [Y2Storage::Devicegraph]
    def checkpoint(device)
      @checkpoints[device.sid]
    end

    # Whether initial devices have been modified
    #
    # @return [Boolean]
    def devices_edited?
      current != initial
    end

  private

    def storage_manager
      Y2Storage::StorageManager.instance
    end
  end
end
