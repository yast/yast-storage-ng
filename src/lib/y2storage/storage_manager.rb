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
require "y2storage/devicegraph_sanitizer"
require "y2storage/disk_analyzer"
require "y2storage/dump_manager"
require "y2storage/callbacks"
require "y2storage/hwinfo_reader"
require "y2storage/sysconfig_storage"
require "yast2/fs_snapshot"

Yast.import "Mode"
Yast.import "Stage"

module Y2Storage
  # Singleton class to provide access to the libstorage Storage object and
  # to store related state information.
  #
  # FIXME: This class exceeds the maximum allowed length (250 lines of code), but
  # there are quite some code that could be extracted to a new place, mainly all
  # stuff related to testing (e.g., {#probe_from_yaml}).
  #
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
    # With the default probe callbacks, the user is asked whether to continue on
    # each error reported by libstorage-ng.
    #
    # With the default sanitize callbacks, the user is asked whether to sanitize
    # the raw probed devicegraph when it contains some error.
    #
    # If this method returns false, #staging and #probed could be in bad state
    # (or not be there at all) so they should not be trusted in the subsequent
    # code.
    #
    # @param probe_callbacks [Callbacks::Activate]
    # @param sanitize_callbacks [Callbacks::Sanitize]
    # @return [Boolean] whether probing was successfull, false if libstorage-ng
    #   found a problem and the corresponding callback returned false (i.e. it
    #   was decided to abort due to the error)
    def probe(probe_callbacks: nil, sanitize_callbacks: nil)
      probe_callbacks ||= Callbacks::Probe.new

      @storage.probe(probe_callbacks)
      probed_performed
      sanitize_probed(sanitize_callbacks)
      DumpManager.dump(@probed_graph)
      true
    rescue Storage::Exception, Error
      false
    end

    # Probed devicegraph, after sanitizing it (see {#sanitize_probed})
    #
    # @note This devicegraph is not exactly the same than the initial
    #   raw probed returned by libstorage-ng. The raw probed can contain
    #   some errors (e.g., incomplete LVM VGs). This probed devicegraph
    #   is the result of sanitizing the initial raw probed.
    #
    # @see #raw_probed
    #
    # @return [Devicegraph]
    def probed
      return @probed_graph if @probed_graph

      probe unless probed?
      @probed_graph
    end

    # Probed devicegraph returned by libstorage-ng (without sanitizing)
    #
    # @see #probed
    #
    # @return [Devicegraph]
    def raw_probed
      @raw_probed ||= begin
        probe unless probed?
        Devicegraph.new(storage.probed)
      end
    end

    # Staging devicegraph
    #
    # @note The initial staging is not exactly the same than the initial staging
    #   returned by libstorage-ng. This staging is initialized from the sanitized
    #   probed devicegraph (see {#sanitize_probed}).
    #
    # @return [Devicegraph]
    def staging
      @staging ||= begin
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

    # System devicegraph
    #
    # It is used to perform actions beforme the commit phase (e.g., immediate unmount).
    #
    # @return [Y2Storage::Devicegraph]
    def system
      @system ||= Devicegraph.new(storage.system)
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
      DumpManager.dump(staging, "committed")

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
      sanitize_probed
    ensure
      storage.remove_devicegraph("fake")
    end

    # Probes from a xml file instead of doing real probing
    def probe_from_xml(xml_file)
      storage.probed.load(xml_file)
      storage.probed.copy(storage.staging)
      storage.probed.copy(storage.system)
      probed_performed
      sanitize_probed
    end

    # Access mode in which the storage system was initialized (read-only or read-write)
    #
    # @see StorageManager.setup
    #
    # @return [Symbol] :ro, :rw
    def mode
      environment.read_only? ? :ro : :rw
    end

    # Whether there is any device in the system that may be used to install a
    # system.
    #
    # This method does not check sizes or any other property of the devices.
    # It performs a very simple check and returns true if there is any device
    # of one of the acceptable types (basically disks or DASDs).
    #
    # It will never trigger a hardware probing. The method works even if
    # such probing has not been performed yet.
    #
    # @return [Boolean]
    def devices_for_installation?
      if probed?
        !probed.disk_devices.empty?
      else
        begin
          Storage.light_probe
        rescue Storage::Exception
          false
        end
      end
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
      @raw_probed = nil
      @probed_graph = nil
      @probed_disk_analyzer = nil
      @committed = false
      Y2Storage::HWInfoReader.instance.reset
    end

    alias_method :probed_changed, :reset_probed

    # Invalidates previous staging devicegraph and its related data
    def reset_staging
      @staging = nil
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
      log.info("Probed devicegraph\n#{raw_probed.to_xml}")

      @staging_revision_after_probing = staging_revision
    end

    # Resets the #staging_revision
    def reset_staging_revision
      @staging_revision = 0
      @staging_revision_after_probing = 0
    end

    # Sanitizes the raw probed devicegraph
    #
    # The raw probed devicegraph can contain some errors (e.g., incomplete LVM VGs).
    # This method tries to fix all errors from raw probed.
    #
    # With the default callbacks, the user is asked whether to sanitize the raw probed
    # devicegraph when it contains some errors.
    #
    # The raw probed devicegraph remains untouched, and the new sanitized one is internally
    # saved and copied into the staging devicegraph.
    #
    # @raise [Y2Storage::Error] if the user decides to not sanitize. In that case, the
    #   probed and staging devicegraphs also remain untouched, but they are useless
    #   for proposal/partitioner.
    #
    # @param callbacks [Y2Storage::Callbacks::Sanitize]
    def sanitize_probed(callbacks = nil)
      callbacks ||= Callbacks::Sanitize.new
      sanitizer = DevicegraphSanitizer.new(raw_probed)

      errors = sanitizer.errors.map(&:message)

      raise Error, "Probed devicegraph is not sanitized" if errors.any? && !callbacks.sanitize?(errors)

      @probed_graph = sanitizer.sanitized_devicegraph
      @probed_graph.safe_copy(staging)

      # Save sanitized devicegraph into logs
      log.info("Sanitized probed devicegraph\n#{probed.to_xml}")
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
      # Initializes storage with a specific access mode (read-only or read-write)
      #
      # With the default callbacks, the user is asked whether to retry or abort
      # when lock cannot be acquired.
      #
      # @raise [AccessModeError] if the requested mode is incompatible with the
      #   already created instance (i.e., current instance is ro but rw is requested).
      #
      # @param mode [Symbol, nil] :ro, :rw. If nil, a default mode is used, see
      #   {.default_storage_mode}.
      # @param callbacks [Callbacks::Initialize, nil]
      #
      # @return [Boolean] true if the storage instance was correctly created for
      #   the given mode; false otherwise.
      def setup(mode: nil, callbacks: nil)
        # In case of mode is not given, it is necessary to initialize it with the
        # default mode due to {.instance} without mode returns the current storage
        # instance. In some cases, the current instance might not be valid for the
        # default mode (e.g., current is read-only but {.setup} is called without
        # mode during installation).
        mode ||= default_storage_mode
        Y2Storage::StorageManager.instance(mode: mode, callbacks: callbacks)
        true
      rescue Yast::AbortException
        false
      end

      # Returns the singleton instance.
      #
      # In the first call, it will create a libstorage instance (using common
      # defaults) if there isn't one yet.
      #
      # With the default callbacks, the user is asked whether to retry or abort
      # when lock cannot be acquired.
      #
      # @see .create_instance if you need special parameters for creating the
      #   libstorage instance.
      # @see .create_test_instance if you just need to create an instance that
      #   ensures not real hardware probing, even calling to #probe.
      #
      # @raise [AccessModeError] if the requested mode is incompatible with the
      #   already created instance (i.e., current instance is ro but rw is requested).
      #
      # @raise [Yast::AbortException] if the storage lock cannot be acquired and
      #   the user decides to abort.
      #
      # @param mode [Symbol, nil] :ro, :rw. If nil, a default mode is used, see
      #   {.default_storage_mode}.
      # @param callbacks [Callbacks::Initialize, nil]
      #
      # @return [StorageManager]
      def instance(mode: nil, callbacks: nil)
        return @instance if @instance && mode.nil?

        mode ||= default_storage_mode

        if @instance
          return @instance if valid_instance?(mode)

          raise AccessModeError,
            "Unexpected storage mode: current is #{@instance.mode}, requested is #{mode}"
        else
          read_only = mode == :ro
          create_instance(Storage::Environment.new(read_only), callbacks)
        end
      end

      # Creates the singleton instance with a customized libstorage object.
      #
      # Create your own Storage::Environment for custom purposes like mocking
      # the hardware probing etc.
      #
      # If no Storage::Environment is provided, it uses a default one that
      # allows hardware probing.

      # With the default callbacks, the user is asked whether to retry or abort
      # when lock cannot be acquired.
      #
      # @raise [Yast::AbortException] if lock cannot be acquired and the user
      #   decides to abort.
      #   Several process can access in read-only mode at the same time, but only
      #   one process can access in read-write mode. If a process is accessing in
      #   read-write mode, no other process can create a new instance.
      #
      # @param environment [Storage::Environment, nil]
      # @param callbacks [Callbacks::Initialize, nil]
      #
      # @return [StorageManager] singleton instance
      def create_instance(environment = nil, callbacks = nil)
        environment ||= Storage::Environment.new(true)
        create_logger
        log.info "Creating Storage object"
        @instance = new(environment)
      rescue Storage::LockException => e
        raise Yast::AbortException unless retry_create_instance?(e, callbacks)

        retry
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

      # Default access mode (read-only or read-write)
      #
      # @note During installation, access mode should be read-write.
      #
      # @return [Symbol] :ro, :rw
      def default_storage_mode
        Yast::Mode.installation ? :rw : :ro
      end

      # Checks whether the current instance can be used for the requested access mode
      #
      # A read-write instance can be always used independendly of the requested mode.
      # In case of a read-only instance, it is only valid if requested mode is read-only.
      #
      # @note The instance is always considered as valid when it is created for
      #   testing purposes.
      #
      # @param requested_mode [Symbol] :ro, :rw
      # @return [Boolean]
      def valid_instance?(requested_mode)
        return false unless @instance
        return true if test_instance?

        @instance.mode == :rw || requested_mode == :ro
      end

      # Whether the current instance is for testing
      #
      # @return [Boolean]
      def test_instance?
        @instance.environment.probe_mode == Storage::ProbeMode_NONE
      end

      # Whether the user decides to retry the creation of the instance
      #
      # It is used when intitial creation could not be done due to lock errors.
      #
      # @see create_instance
      #
      # @param error [Storage::LockException]
      # @param callbacks [Callbacks::Initialize]
      #
      # @return [Boolean] true if the user decides to retry.
      def retry_create_instance?(error, callbacks)
        callbacks ||= Callbacks::Initialize.new(error)
        callbacks.retry?
      end
    end
    # rubocop:enable Metrics/ClassLength

    # Logger class for libstorage. This is needed to make libstorage log to the
    # y2log.
    class StorageLogger < ::Storage::Logger
      # rubocop:disable Metrics/ParameterLists
      def write(level, component, filename, line, function, content)
        # libstorage pretent that it use same logging as y2_logger but y2_logger support also
        # parameter expansion via printf, so we need double escaping to prevent this expansion
        # (bsc#1091062)
        content = content.gsub(/%/, "%%")
        Yast.y2_logger(level, component, filename, line, function, content)
      end
      # rubocop:enable Metrics/ParameterLists
    end
  end
end
