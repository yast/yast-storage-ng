# Copyright (c) [2015-2022] SUSE LLC
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
require "y2storage/arch"
require "y2storage/fake_device_factory"
require "y2storage/devicegraph"
require "y2storage/probed_devicegraph_checker"
require "y2storage/devicegraph_sanitizer"
require "y2storage/disk_analyzer"
require "y2storage/dump_manager"
require "y2storage/callbacks"
require "y2storage/hwinfo_reader"
require "y2storage/configuration"
require "y2storage/storage_wrapper"
require "yast2/fs_snapshot"
require "y2issues/list"

Yast.import "Mode"
Yast.import "Stage"
Yast.import "Pkg"

module Y2Storage
  # Singleton class to provide access to the libstorage Storage object and
  # to store related state information.
  #
  # FIXME: This class contains some responsibilities (and code) that could
  # be extracted to a new place, mainly all stuff related to testing
  # (e.g., {#probe_from_yaml}).
  #
  class StorageManager # rubocop:disable Metrics/ClassLength
    include Yast::Logger
    extend Forwardable

    # @return [Storage::Storage] Storage wrapper
    attr_reader :wrapper

    def_delegators :@wrapper, :environment, :rootprefix, :prepend_rootprefix, :rootprefix=, :arch,
      :probed?, :activate, :deactivate, :activate, :deactivate, :raw_probed, :staging, :staging=,
      :staging_revision, :system, :proposal=, :probed_disk_analyzer, :staging_changed?, :committed?,
      :mode, :configuration, :proposal, :commit, :devices_for_installation?, :storage

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
      @wrapper = Y2Storage::StorageWrapper.new(storage_environment)
    end

    # Probes all storage devices
    #
    # If this method returns false, #staging and #probed could be in bad state
    # (or not be there at all) so they should not be trusted in the subsequent
    # code.
    #
    # @see #probe!
    #
    # @param probe_callbacks [Callbacks::Probe, nil]
    # @return [Boolean] whether probing was successful, false if libstorage-ng
    #   found a problem and the corresponding callback returned false (i.e. it
    #   was decided to abort due to the error)
    def probe(probe_callbacks: nil)
      probe!(probe_callbacks: probe_callbacks)
      true
    rescue Storage::Exception, Yast::AbortException => e
      log.error("ERROR: #{e.message}")

      false
    end

    # Probes all storage devices
    #
    # Invalidates the probed and staging devicegraph. Real probing is
    # only performed when the instance is not for testing.
    #
    # With the default probe callbacks, the errors reported by libstorage-ng are stored in the
    # {#probe_issues} list.
    #
    # @raise [Storage::Exception, Yast::AbortException] when probe fails
    #
    # @param probe_callbacks [Callbacks::Probe, nil]
    def probe!(probe_callbacks: nil)
      # Release all sources before probing. Otherwise, unmount action could fail if the mount point
      # of the software source device is modified. Note that this is only necessary during the
      # installation because libstorage-ng would try to unmount from the chroot path
      # (e.g., /mnt/mount/point) and there is nothing mounted there.
      Yast::Pkg.SourceReleaseAll if Yast::Mode.installation

      @wrapper.probe(probe_callbacks: probe_callbacks)
      manage_probing_issues
      DumpManager.dump(@wrapper.probed)

      nil
    end

    # Probed devicegraph, after sanitizing it (see {#manage_probing_issues})
    #
    # @note This devicegraph is not exactly the same than the initial
    #   raw probed returned by libstorage-ng. The raw probed can contain
    #   some errors (e.g., incomplete LVM VGs). This probed devicegraph
    #   is the result of sanitizing the initial raw probed.
    #
    # @raise [Storage::Exception, Yast::AbortException] when probe fails
    #
    # @return [Devicegraph]
    def probed
      probe! unless probed?
      @wrapper.probed
    end

    # Staging devicegraph
    #
    # @note The initial staging is not exactly the same than the initial staging
    #   returned by libstorage-ng. This staging is initialized from the sanitized
    #   probed devicegraph (see {#manage_probing_issues}).
    #
    # @raise [Storage::Exception, Yast::AbortException] when probe fails
    #
    # @return [Devicegraph]
    def staging
      probe! unless probed?
      @wrapper.staging
    end

    # Probes from a yml file instead of doing real probing
    def probe_from_yaml(yaml_file = nil)
      @wrapper.probe_from_yaml(yaml_file)
      manage_probing_issues
    end

    # Probes from a xml file instead of doing real probing
    def probe_from_xml(xml_file)
      @wrapper.probe_from_xml(xml_file)
      manage_probing_issues
    end

    private

    # Manages issues detected during the probing phase
    #
    # The raw probed devicegraph is sanitized in order to fix the issues (e.g., when there are incomplete
    # LVM VGs).
    #
    # The raw probed devicegraph remains untouched, and the new sanitized one is internally saved and
    # copied into the staging devicegraph.
    #
    # @raise [Yast::AbortException] if the user decides to not continue. In that case, the probed
    #   and staging devicegraphs also remain untouched, but they are useless for
    #   proposal/partitioner.
    def manage_probing_issues
      continue = raw_probed.issues_manager.report_probing_issues
      raise Yast::AbortException, "Devicegraph contains errors. User has aborted." unless continue

      @wrapper.sanitize_devicegraph
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
