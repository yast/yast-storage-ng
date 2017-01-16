#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
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
require "storage"
require "y2storage/fake_device_factory"

module Y2Storage
  #
  # Singleton class to provide access to the libstorage object and associated
  # information.
  #
  class StorageManager
    include Yast::Logger
    extend Forwardable

    # Libstorage object
    #
    # Calls to #probed, #staging, #environment and #arch are forwarded to this
    # object.
    #
    # @return [Storage::Storage]
    attr_reader :storage

    # Revision of the staging devicegraph.
    #
    # Zero means no modification (staging looks like probed). Incremented every
    # time the staging devicegraph is re-assigned.
    # @see #copy_to_staging
    #
    # @return [Fixnum]
    attr_reader :staging_revision

    def_delegators :@storage, :probed, :staging, :environment, :arch

    def initialize(storage_environment)
      @storage = Storage::Storage.new(storage_environment)
      @staging_revision = 0
    end

    # Sets the devicegraph as the staging one, updating all the associated
    # information like #staging_revision
    #
    # @param [Storage::Devicegraph] devicegraph to copy
    def copy_to_staging(devicegraph)
      devicegraph.copy(storage.staging)
      update_staging_revision
    end

    # Increments #staging_revision
    #
    # To be called explicitly if the staging devicegraph is modified without
    # using #copy_to_staging
    def update_staging_revision
      @staging_revision += 1
    end

    #
    # Class methods
    #
    class << self
      # Returns the singleton instance.
      #
      # In the first call, it will create a libstorage instance (using common
      # defaults) if there isn't one yet. That means that, by default, the first
      # call will also trigger hardware probing.
      #
      # @see .create_instance if you need special parameters for creating the
      #   libstorage instance
      # @see .create_test_instance if you just need to create an instance
      #   without hardware probing
      # @see .fake_from_yaml for easy mocking
      #
      # @return [StorageManager]
      #
      def instance
        create_instance unless @instance
        @instance
      end

      # Creates the singleton instance with a customized libstorage object.
      #
      # Create your own Storage::Environment for custom purposes like mocking
      # the hardware probing etc.
      #
      # If no Storage::Environment is provided, it uses a default one that
      # implies hardware probing. This is why there is an alias
      # StorageManager.start_probing to make this explicit.
      #
      # @return [StorageManager] singleton instance
      #
      def create_instance(storage_environment = nil)
        storage_environment ||= ::Storage::Environment.new(true)
        create_logger
        log.info("Creating Storage object")
        @instance = new(storage_environment)
      end

      alias_method :start_probing, :create_instance

      # Use this as an alternative to the instance method.
      # Probing is skipped and the device tree is initialized from yaml_file.
      # Any existing probed device tree is replaced.
      #
      # @return [StorageManager] singleton instance
      #
      def fake_from_yaml(yaml_file = nil)
        @instance ||= create_test_instance
        fake_graph = @instance.storage.create_devicegraph("fake")
        Y2Storage::FakeDeviceFactory.load_yaml_file(fake_graph, yaml_file) if yaml_file
        fake_graph.copy(@instance.storage.probed)
        fake_graph.copy(@instance.storage.staging)
        @instance.storage.remove_devicegraph("fake")
        @instance
      end

      # Creates the singleton instance skipping hardware probing.
      #
      # @return [StorageManager] singleton instance
      #
      def create_test_instance
        create_instance(test_environment)
      end

      # Make sure only instance can be used to create objects
      private :new, :allocate

    private

      def test_environment
        read_only = true
        Storage::Environment.new(read_only, Storage::ProbeMode_NONE, Storage::TargetMode_DIRECT)
      end

      def create_logger
        # Store the reference in a class instance variable to prevent the
        # garbage collector from cleaning too much
        @logger = StorageLogger.new
        ::Storage.logger = @logger
      end
    end

    # Logger class for libstorage. This is needed to make libstorage log to the
    # y2log.
    class StorageLogger < ::Storage::Logger
      # rubocop:disable Metrics/ParameterLists
      def write(level, component, filename, line, function, content)
        Yast.y2_logger(level, component, filename, line, function, content)
      end
      # rubocop:enable Metrics/ParameterLists
    end
  end
end
