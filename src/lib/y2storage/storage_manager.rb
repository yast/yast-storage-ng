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
  # Singleton class for the libstorage object.
  #
  # You can simply use StorageManager.instance to use it and create a
  # libstorage instance if there isn't one yet; this will use common default
  # parameters for creating it.
  #
  # If you need special parameters for creating it, you can use
  # StorageManager.create_instance with a custom ::Storage::Environment
  #
  # By default (unless disabled in the ::Storage::Environment), creating the
  # instance will also start hardware probing. This is why there is an alias
  # name StorageManager.start_probing to make this explicit.
  #
  class StorageManager
    include Yast::Logger
    #
    # Class methods
    #
    class << self
      # Return the singleton for the libstorage object. This will create one
      # for the first call, which will also trigger hardware probing.
      #
      # @return [::Storage::Storage] libstorage object
      #
      def instance
        create_instance unless @instance
        @instance
      end

      # Use this as an alternative to the instance method.
      # Probing is skipped and the device tree is initialized from yaml_file.
      # Any existing probed device tree is replaced.
      #
      # @return [::Storage::Storage] libstorage object
      #
      def fake_from_yaml(yaml_file = nil)
        @instance ||= create_instance(
          ::Storage::Environment.new(true, ::Storage::ProbeMode_NONE, ::Storage::TargetMode_DIRECT)
        )
        fake_graph = @instance.create_devicegraph("fake")
        Y2Storage::FakeDeviceFactory.load_yaml_file(fake_graph, yaml_file) if yaml_file
        # FIXME: Arvin plans some replace_devicegraph() feature in libstorage;
        # adjust code when it's done
        @instance.remove_devicegraph("probed")
        @instance.copy_devicegraph("fake", "probed")
        @instance.remove_devicegraph("fake")
        @instance
      end

      # Create the singleton for the libstorage object.
      #
      # Create your own Storage::Environment for custom purposes like mocking
      # the hardware probing etc.
      #
      # If no Storage::Environment is provided, it creates one based on the
      # value of environment variable YAST2_STORAGE_PROBE_MODE
      #
      # @return [::Storage::Storage] libstorage object
      #
      def create_instance(storage_environment = nil)
        storage_environment ||= ::Storage::Environment.new(true)
        create_logger
        log.info("Creating Storage object")
        @instance = ::Storage::Storage.new(storage_environment)
      end

      alias_method :start_probing, :create_instance

    private

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
