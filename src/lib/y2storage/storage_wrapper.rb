# Copyright (c) [2022] SUSE LLC
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

module Y2Storage
  class StorageWrapper
    include Yast::Logger
    extend Forwardable

    # Libstorage object
    #
    # Calls to several methods (e.g., #environment and #rootprefix) are forwarded to this object.
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

    def_delegators :@storage, :environment, :rootprefix, :prepend_rootprefix, :rootprefix=,
      :arch

    # @!method rootprefix
    #   @return [String] root prefix used by libstorage

    # @!method rootprefix=(path)
    #   Sets the root prefix used by libstorage in subsequent operations
    #   @param path [String]

    # @!method prepend_rootprefix(path)
    #   Prepends the current libstorage root prefix to a path, if necessary
    #   @param path [String] original path (without prefix)
    #   @return [String]

    # @!method arch
    #   Returns the architecture according to libstorage
    #   @return [Storage::Arch]

    # @param storage_environment [::Storage::Environment]
    def initialize(storage_environment)
      @storage = Storage::Storage.new(storage_environment)
      configuration.apply_defaults

      @probed = false
      @activate_issues = Y2Issues::List.new
      @probe_issues = Y2Issues::List.new
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
    # hand, after calling this function the system should be probed.
    #
    # With the default callbacks, every question about activating a given
    # technology is forwarded to the user using pop up dialogs. In addition,
    # errors reported by libstorage-ng are stored in the {#activate_issues} list.
    #
    # @param callbacks [Callbacks::Activate, nil]
    # @return [Boolean] whether activation was successful
    def activate(callbacks = nil)
      activate_callbacks = callbacks || Callbacks::Activate.new
      @storage.activate(activate_callbacks)
      @activate_issues = activate_callbacks.issues
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
    def probe(probe_callbacks: nil)
      probe_callbacks ||= Callbacks::Probe.new

      begin
        @storage.probe(probe_callbacks)
      rescue Storage::Aborted
        retry if probe_callbacks.again?

        raise
      end

      @probe_issues = probe_callbacks.issues
      probe_performed

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
    #   probed devicegraph (see {#manage_probing_issues}).
    #
    # @raise [Storage::Exception, Yast::AbortException] when probe fails
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

    # Performs in the system all the necessary operations to make it match the staging devicegraph.
    #
    # Beware: this method can cause data loss
    #
    # The user is asked whether to continue on each error reported by libstorage-ng.
    #
    # @param force_rw [Boolean] if mount points should be forced to have read/write permissions.
    # @param callbacks [Y2Storage::Callbacks::Commit]
    #
    # @return [Boolean] whether commit was successful, false if libstorage-ng found a problem and it was
    #   decided to abort.
    def commit(force_rw: false, callbacks: nil)
      callbacks ||= Callbacks::Commit.new

      staging.pre_commit

      storage.calculate_actiongraph
      commit_options = ::Storage::CommitOptions.new(force_rw)

      # Save committed devicegraph into logs
      log.info("Committed devicegraph\n#{staging.to_xml}")
      DumpManager.dump(staging, "committed")

      # Log libstorage-ng checks
      staging.check

      storage.commit(commit_options, callbacks)
      staging.post_commit

      @committed = true
    rescue Storage::Exception
      false
    end

    # Probes from a yml file instead of doing real probing
    # TODO: YaST specific
    def probe_from_yaml(yaml_file = nil)
      fake_graph = Devicegraph.new(storage.create_devicegraph("fake"))
      Y2Storage::FakeDeviceFactory.load_yaml_file(fake_graph, yaml_file) if yaml_file

      fake_graph.to_storage_value.copy(storage.probed)
      fake_graph.to_storage_value.copy(storage.staging)
      fake_graph.to_storage_value.copy(storage.system)

      probe_performed
    ensure
      storage.remove_devicegraph("fake")
    end

    # Probes from a xml file instead of doing real probing
    # TODO: YaST specific
    def probe_from_xml(xml_file)
      storage.probed.load(xml_file)
      storage.probed.copy(storage.staging)
      storage.probed.copy(storage.system)
      probe_performed
    end

    # Access mode in which the storage system was initialized (read-only or read-write)
    #
    # @see StorageManager.setup
    #
    # @return [Symbol] :ro, :rw
    def mode
      environment.read_only? ? :ro : :rw
    end

    def light_probe
      Storage.light_probe
    rescue Storage::Exception
      false
    end

    # Configuration of Y2Storage
    #
    # @return [Configuration]
    def configuration
      @configuration ||= Configuration.new(@storage)
    end

    def sanitize_devicegraph
      sanitizer = DevicegraphSanitizer.new(raw_probed)

      @probed_graph = sanitizer.sanitized_devicegraph
      @probed_graph.safe_copy(staging)

      # Save sanitized devicegraph into logs
      log.info("Sanitized probed devicegraph\n#{probed.to_xml}")
    end

    private

    # Value of #staging_revision right after executing the latest libstorage
    # probing.
    #
    # Used to check if the system has been re-probed
    #
    # @return [Integer]
    attr_reader :staging_revision_after_probing

    # Issues detected while activating devices
    #
    # @return [Y2Issues::List<Issue>]
    attr_reader :activate_issues

    # Issues detected while probing the system
    #
    # @return [Y2Issues::List<Issue>]
    attr_reader :probe_issues

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
      # Invalidate probed and its two derivative devicegraphs
      @raw_probed = @probed_graph = @system = nil

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
    def probe_performed
      @probed = true
      probed_changed
      staging_changed

      # Save probed devicegraph into logs
      log.info("Probed devicegraph\n#{raw_probed.to_xml}")

      @staging_revision_after_probing = staging_revision

      # Probing issues will contain issues detected on activate and probe callbacks, and also issues
      # detected after checking the probed devicegraph.
      issues = activate_issues.concat(probe_issues)
      issues.concat(ProbedDevicegraphChecker.new(raw_probed).issues)

      raw_probed.issues_manager.probing_issues = issues
    end

    # Resets the #staging_revision
    def reset_staging_revision
      @staging_revision = 0
      @staging_revision_after_probing = 0
    end

  end
end
