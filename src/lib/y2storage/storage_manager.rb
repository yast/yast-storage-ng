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
require "y2storage/hwinfo_reader"
require "y2storage/sysconfig_storage"
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
      apply_storage_defaults

      @probed = false
      reset_probed
      reset_staging
      reset_staging_revision
    end

    # Default value for mount_by option
    #
    # @note This value is initialized with the value from {SysconfigStorage}.
    #
    # @see #apply_storage_defaults
    #
    # @return [Filesystems::MountByType]
    def default_mount_by
      Filesystems::MountByType.new(@storage.default_mount_by)
    end

    # Sets the default mount_by value
    #
    # @param mount_by [Filesystems::MountByType]
    def default_mount_by=(mount_by)
      @storage.default_mount_by = mount_by.to_storage_value
    end

    # Updates sysconfig values
    def update_sysconfig
      SysconfigStorage.instance.default_mount_by = default_mount_by
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
    # hand, after calling this function the system should be probed.
    #
    # With the default callbacks, every question about activating a given
    # technology is forwarded to the user using pop up dialogs. In addition,
    # the user is asked whether to continue on errors reported by libstorage-ng.
    #
    # @param callbacks [Callbacks::Activate]
    # @return [Boolean] whether activation was successfull, false if
    #   libstorage-ng found a problem and the corresponding callback returned
    #   false (i.e. it was decided to abort due to the error)
    def activate(callbacks = nil)
      activate_callbacks = callbacks || Callbacks::Activate.new
      @storage.activate(activate_callbacks)
      true
    rescue Storage::Exception
      false
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
    # With the default callbacks, the user is asked whether to continue on
    # each error reported by libstorage-ng.
    #
    # If this method returns false, #staging and #probed could be in bad state
    # (or not be there at all) so they should not be trusted in the subsequent
    # code.
    #
    # @param callbacks [Callbacks::Activate]
    # @return [Boolean] whether probing was successfull, false if libstorage-ng
    #   found a problem and the corresponding callback returned false (i.e. it
    #   was decided to abort due to the error)
    def probe(callbacks = nil)
      probe_callbacks = callbacks || Callbacks::Probe.new
      @storage.probe(probe_callbacks)
      probed_performed
      true
    rescue Storage::Exception
      false
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

    # Checks whether the staging devicegraph has been committed to the system.
    #
    # @see #commit
    #
    # If this is false, the probed devicegraph (see {#probed}) should perfectly
    # match the real current system... as long as the system has not been
    # modified externally to YaST, which is impossible to control.
    #
    # @return [Boolean]
    def committed?
      @committed
    end

    # Performs in the system all the necessary operations to make it match the
    # staging devicegraph.
    #
    # Beware: this method can cause data loss
    #
    # The user is asked whether to continue on each error reported by
    # libstorage-ng.
    #
    # @return [Boolean] whether commit was successfull, false if libstorage-ng
    #   found a problem and it was decided to abort due to that
    def commit(force_rw: false)
      # Tell FsSnapshot whether Snapper should be configured later
      Yast2::FsSnapshot.configure_on_install = configure_snapper?
      callbacks = Callbacks::Commit.new
      storage.calculate_actiongraph
      commit_options = ::Storage::CommitOptions.new(force_rw)

      # Save committed devicegraph into logs
      log.info("Committed devicegraph\n#{staging.to_xml}")

      storage.commit(commit_options, callbacks)
      @committed = true
    rescue Storage::Exception
      false
    end

    # Probes from a yml file instead of doing real probing
    def probe_from_yaml(yaml_file = nil)
      fake_graph = Devicegraph.new(storage.create_devicegraph("fake"))
      Y2Storage::FakeDeviceFactory.load_yaml_file(fake_graph, yaml_file) if yaml_file

      fake_graph.to_storage_value.copy(storage.probed)
      fake_graph.to_storage_value.copy(storage.staging)
      fake_graph.to_storage_value.copy(storage.system)

      probed_performed
    ensure
      storage.remove_devicegraph("fake")
    end

    # Probes from a xml file instead of doing real probing
    def probe_from_xml(xml_file)
      storage.probed.load(xml_file)
      storage.probed.copy(storage.staging)
      storage.probed.copy(storage.system)
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

    # Sets default values for Storage object
    #
    # @see SysconfigStorage
    def apply_storage_defaults
      self.default_mount_by = SysconfigStorage.instance.default_mount_by
    end

    # Sets the devicegraph as the staging one, updating all the associated
    # information like #staging_revision
    #
    # @param [Devicegraph] devicegraph to copy
    def copy_to_staging(devicegraph)
      devicegraph.safe_copy(staging)
      staging_changed
    end

    # Invalidates previous probed devicegraph and its related data
    def reset_probed
      @probed_graph = nil
      @probed_disk_analyzer = nil
      @committed = false
      Y2Storage::HWInfoReader.instance.reset
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

    # Sets all necessary data after probing. To be executed always after probing.
    def probed_performed
      @probed = true
      probed_changed
      staging_changed

      # Save probed devicegraph into logs
      log.info("Probed devicegraph\n#{probed.to_xml}")

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
