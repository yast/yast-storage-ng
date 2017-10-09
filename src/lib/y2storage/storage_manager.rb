#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015,2017] SUSE LLC
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
require "y2storage/devicegraph"
require "y2storage/disk_analyzer"
require "y2storage/callbacks"
require "yast2/fs_snapshot"

Yast.import "Mode"
Yast.import "Stage"

module Y2Storage
  # Singleton class to provide access to the libstorage Storage object and
  # to store related state information.
  class StorageManager
    include Yast::Logger
    extend Forwardable

    # Libstorage object
    #
    # Calls to several methods (e.g. #environment, #arch and #rootprefix) are
    # forwarded to this object.
    #
    # @return [Storage::Storage]
    attr_reader :storage

    # Revision of the staging devicegraph.
    #
    # Zero means no modification (still not probed). Incremented every
    # time the staging devicegraph is re-assigned.
    # @see #copy_to_staging
    # @see #staging_changed
    #
    # @return [Integer]
    attr_reader :staging_revision

    # Proposal that was used to calculate the current staging devicegraph.
    #
    # Nil if the devicegraph was set manually and not by accepting a proposal.
    #
    # @return [GuidedProposal, nil]
    attr_reader :proposal

    def_delegators :@storage, :environment, :arch, :rootprefix, :prepend_rootprefix, :rootprefix=

    # @!method rootprefix
    #   @return [String] root prefix used by libstorage

    # @!method rootprefix=(path)
    #   Sets the root prefix used by libstorage in subsequent operations
    #   @param path [String]

    # @!method prepend_rootprefix(path)
    #   Prepends the current libstorage root prefix to a path, if necessary
    #   @param path [String] original path (without prefix)
    #   @return [String]

    # @param storage_environment [::Storage::Environment]
    def initialize(storage_environment)
      @storage = Storage::Storage.new(storage_environment)
      @probed = false
      reset_probed
      reset_staging
      reset_staging_revision
    end

    # Whether probing has been done
    # @return [Boolean]
    def probed?
      @probed
    end

    # Increments #staging_revision
    #
    # To be called explicitly if the staging devicegraph is modified without
    # using #staging= or #proposal=
    def increase_staging_revision
      @staging_revision += 1
    end

    # Activate devices like multipath, MD and DM RAID, LVM and LUKS. It is not
    # required to have probed the system to call this function. On the other
    # hand after calling this function the system should be probed.
    #
    # @raise [Exception] if error during activation
    def activate
      activate_callbacks = Callbacks::Activate.new
      @storage.activate(activate_callbacks)
    end

    # Deactivate devices like multipath, MD and DM RAID, LVM and LUKS. It is
    # not required to have probed the system to call this function. On the
    # other hand after calling this function the system should be probed.
    #
    # @return [Storage::DeactivateStatus] status of subsystems, see
    #   libstorage-ng documentation for details.
    def deactivate
      @storage.deactivate
    end

    # Probes all storage devices.
    #
    # Invalidates the probed and staging devicegraph. Real probing is
    # only performed when the instance is not for testing.
    #
    # @raise [Exception] if error during probing
    def probe
      @storage.probe
      probed_performed
    end

    # Probed devicegraph
    # @return [Devicegraph]
    def probed
      @probed_graph ||= begin
        probe unless probed?
        Devicegraph.new(storage.probed)
      end
    end

    # Staging devicegraph
    # @return [Devicegraph]
    def staging
      @staging_graph ||= begin
        probe unless probed?
        Devicegraph.new(storage.staging)
      end
    end

    # Copies the manually-calculated (no proposal) devicegraph to staging.
    #
    # If the devicegraph was calculated by means of a proposal, use #proposal=
    # instead.
    # @see #proposal=
    #
    # @param [Devicegraph] devicegraph to copy
    def staging=(devicegraph)
      copy_to_staging(devicegraph)
    end

    # Stores the proposal, modifying the staging devicegraph and all the related
    # information.
    #
    # @param proposal [GuidedProposal]
    def proposal=(proposal)
      copy_to_staging(proposal.devices)
      @proposal = proposal
    end

    # Disk analyzer used to analyze the probed devicegraph
    #
    # @return [DiskAnalyzer]
    def probed_disk_analyzer
      @probed_disk_analyzer ||= DiskAnalyzer.new(probed)
    end

    # Checks whether the staging devicegraph has been previously set, either
    # manually or through a proposal.
    #
    # @return [Boolean] false if the staging devicegraph is just the result of
    #   probing (so a direct copy of #probed), true otherwise.
    def staging_changed?
      staging_revision != staging_revision_after_probing
    end

    # Performs in the system all the necessary operations to make it match the
    # staging devicegraph.
    #
    # Beware: this method can cause data loss
    def commit(force_rw: false)
      # Tell FsSnapshot whether Snapper should be configured later
      Yast2::FsSnapshot.configure_on_install = configure_snapper?
      callbacks = Callbacks::Commit.new
      storage.calculate_actiongraph
      commit_options = ::Storage::CommitOptions.new(force_rw)
      storage.commit(commit_options, callbacks)
    end

    # Probes from a yml file instead of doing real probing
    def probe_from_yaml(yaml_file = nil)
      fake_graph = Devicegraph.new(storage.create_devicegraph("fake"))
      Y2Storage::FakeDeviceFactory.load_yaml_file(fake_graph, yaml_file) if yaml_file

      fake_graph.to_storage_value.copy(storage.probed)
      fake_graph.to_storage_value.copy(storage.staging)

      probed_performed
    ensure
      storage.remove_devicegraph("fake")
    end

    # Probes from a xml file instead of doing real probing
    def probe_from_xml(xml_file)
      storage.probed.load(xml_file)
      storage.probed.copy(storage.staging)
      probed_performed
    end

  private

    # Value of #staging_revision right after executing the latest libstorage
    # probing.
    #
    # Used to check if the system has been re-probed
    #
    # @return [Integer]
    attr_reader :staging_revision_after_probing

    # Sets the devicegraph as the staging one, updating all the associated
    # information like #staging_revision
    #
    # @param [Devicegraph] devicegraph to copy
    def copy_to_staging(devicegraph)
      devicegraph.copy(staging)
      staging_changed
    end

    # Invalidates previous probed devicegraph and its related data
    def reset_probed
      @probed_graph = nil
      @probed_disk_analyzer = nil
    end

    alias_method :probed_changed, :reset_probed

    # Invalidates previous staging devicegraph and its related data
    def reset_staging
      @staging_graph = nil
      @proposal = nil
    end

    # Sets all necessary data after changing the staging devicegraph. To be executed
    # always after a staging assignment
    def staging_changed
      reset_staging
      increase_staging_revision
    end

    # Sets all necessary data after probing. To be executed always after probing
    def probed_performed
      @probed = true
      probed_changed
      staging_changed

      @staging_revision_after_probing = staging_revision
    end

    # Resets the #staging_revision
    def reset_staging_revision
      @staging_revision = 0
      @staging_revision_after_probing = 0
    end

    # Whether the final steps to configure Snapper should be performed by YaST
    # at the end of the installation process.
    #
    # @return [Boolean]
    def configure_snapper?
      if !Yast::Mode.installation || !Yast::Stage.initial
        log.info "Not a fresh installation. Don't configure Snapper."
        return false
      end

      root = staging.filesystems.find(&:root?)
      if !root
        log.info "No root filesystem in staging. Don't configure Snapper."
        return false
      end

      if !root.respond_to?(:configure_snapper)
        log.info "The root filesystem can't configure snapper."
        return false
      end

      log.info "Configure Snapper? #{root.configure_snapper}"
      root.configure_snapper
    end

    # Class methods
    class << self
      # Returns the singleton instance.
      #
      # In the first call, it will create a libstorage instance (using common
      # defaults) if there isn't one yet.
      #
      # @see .create_instance if you need special parameters for creating the
      #   libstorage instance.
      # @see .create_test_instance if you just need to create an instance that
      #   ensures not real hardware probing, even calling to #probe.
      #
      # @return [StorageManager]
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
      # allows hardware probing.
      #
      # @return [StorageManager] singleton instance
      def create_instance(storage_environment = nil)
        storage_environment ||= ::Storage::Environment.new(true)
        create_logger
        log.info("Creating Storage object")
        @instance = new(storage_environment)
      end

      # Creates the singleton instance for testing.
      # This instance avoids to perform real probing or commit.
      #
      # @return [StorageManager] singleton instance
      def create_test_instance
        create_instance(test_environment)
      end

      # Make sure only .instance can be used to create objects
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
