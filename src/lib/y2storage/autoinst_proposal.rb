# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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
require "y2storage/proposal_settings"
require "y2storage/exceptions"
require "y2storage/planned"
require "y2storage/proposal"

module Y2Storage
  # Class to calculate a storage proposal for autoinstallation
  #
  # @example Creating a proposal from the current AutoYaST profile
  #   partitioning = Yast::Profile.current["partitioning"]
  #   proposal = Y2Storage::AutoinstProposal.new(partitioning: partitioning)
  #   proposal.proposed?            # => false
  #   proposal.devices              # => nil
  #   proposal.planned_devices      # => nil
  #
  #   proposal.propose              # Performs the calculation
  #
  #   proposal.proposed?            # => true
  #   proposal.devices              # => Proposed layout
  #
  class AutoinstProposal < Proposal::Base
    # @return [Hash] Partitioning layout from an AutoYaST profile
    attr_reader :partitioning

    # @return [AutoinstIssues::List] List of found AutoYaST issues
    attr_reader :issues_list

    # @return [DiskSize] Missing space for the originally planned devices
    attr_reader :missing_space

    # Constructor
    #
    # @param partitioning [Array<Hash>] Partitioning schema from an AutoYaST profile
    # @param devicegraph  [Devicegraph] starting point. If nil, then probed devicegraph
    #   will be used
    # @param disk_analyzer [DiskAnalyzer] by default, the method will create a new one
    #   based on the initial devicegraph or will use the one in {StorageManager} if
    #   starting from probed (i.e. 'devicegraph' argument is also missing)
    # @param issues_list [AutoinstIssues::List] List of AutoYaST issues to register them
    def initialize(partitioning: [], devicegraph: nil, disk_analyzer: nil, issues_list: nil)
      super(devicegraph: devicegraph, disk_analyzer: disk_analyzer)
      @issues_list = issues_list || Y2Storage::AutoinstIssues::List.new
      @partitioning = AutoinstProfile::PartitioningSection.new_from_hashes(partitioning)
    end

  private

    # Calculates the proposal
    #
    # @raise [NoDiskSpaceError] if there is no enough space to perform the installation
    def calculate_proposal
      drives = Proposal::AutoinstDrivesMap.new(initial_devicegraph, partitioning, issues_list)
      if issues_list.fatal?
        @devices = []
        return @devices
      end

      @devices = propose_devicegraph(initial_devicegraph, drives)
    end

    # Proposes a devicegraph based on given drives map
    #
    # This method falls back to #proposed_guided_devicegraph when the device map
    # does not contain any partition.
    #
    # @param devicegraph [Devicegraph]                 Starting point
    # @param drives      [Proposal::AutoinstDrivesMap] Devices map from an AutoYaST profile
    # @return [Devicegraph] Devicegraph containing the planned devices
    def propose_devicegraph(devicegraph, drives)
      if drives.partitions?
        @planned_devices = plan_devices(devicegraph, drives)

        devicegraph = clean_graph(devicegraph, drives, @planned_devices)
        add_partition_tables(devicegraph, drives)

        result = create_devices(devicegraph, @planned_devices, drives.disk_names)
        add_reduced_devices_issues(result)
        @missing_space = result.missing_space
        result.devicegraph
      else
        log.info "No partitions were specified. Falling back to guided setup planning."
        propose_guided_devicegraph(devicegraph, drives)
      end
    end

    # Add partition tables
    #
    # This method create/change partitions tables according to information
    # specified in the profile. Disks containing any partition will be ignored.
    #
    # The devicegraph which is passed as first argument will be modified.
    #
    # @param devicegraph [Devicegraph]                 Starting point
    # @param drives      [Proposal::AutoinstDrivesMap] Devices map from an AutoYaST profile
    def add_partition_tables(devicegraph, drives)
      drives.each do |disk_name, drive_spec|
        next unless drive_spec.partition_table?
        disk = devicegraph.disk_devices.find { |d| d.name == disk_name }
        next if disk.nil? || !disk.partitions.empty?

        update_partition_table(disk, suitable_ptable_type(disk, drive_spec))
      end
    end

    # Determines which partition table type should be used
    #
    # @param disk        [Y2Storage::Disk] Disk to set the partition table on
    # @param drive_spec  [Y2Storage::AutoinstProfile::DriveSection] Drive section from the profile
    # @return [Y2Storage::PartitionTables::Type] Partition table type
    def suitable_ptable_type(disk, drive_spec)
      ptable_type = nil
      if drive_spec.disklabel
        ptable_type = Y2Storage::PartitionTables::Type.find(drive_spec.disklabel)
      end

      disk_ptable_type = disk.partition_table ? disk.partition_table.type : nil
      ptable_type || disk_ptable_type || disk.preferred_ptable_type
    end

    # Update partition table
    #
    # It does nothing if current partition table type and wanted one are the same.
    # The disk object is modified.
    #
    # @param disk        [Y2Storage::Disk] Disk to set the partition table on
    # @param ptable_type [Y2Storage::PartitionTables::Type] Partition table type
    def update_partition_table(disk, ptable_type)
      return if disk.partition_table && disk.partition_table.type == ptable_type
      disk.remove_descendants if disk.partition_table
      disk.create_partition_table(ptable_type)
    end

    # Add devices to make the system bootable
    #
    # The devicegraph which is passed as first argument will be modified.
    #
    # @param devicegraph [Devicegraph]         Starting point
    # @return [Array<Planned::DevicesCollection>] List of required planned devices to boot
    def boot_devices(devicegraph, devices)
      return unless root?(devices.mountable)
      checker = BootRequirementsChecker.new(devicegraph, planned_devices: devices.mountable)
      checker.needed_partitions
    end

    # Determines whether the list of devices includes a root partition
    #
    # @param  devices [Array<Planned:Device>] List of planned devices
    # @return [Boolean] true if there is a root partition; false otherwise.
    def root?(devices)
      return true if devices.any? { |d| d.respond_to?(:mount_point) && d.mount_point == "/" }
      issues_list.add(:missing_root)
    end

    # Finds a suitable devicegraph using the guided proposal approach
    #
    # If the :desired target fails, it will retry with the :min target.
    #
    # @param devicegraph [Devicegraph]       Starting point
    # @param drives      [AutoinstDrivesMap] Devices map from an AutoYaST profile
    # @return [Devicegraph] Proposed devicegraph using the guided proposal approach
    #
    # @raise [Error] No suitable devicegraph was found
    # @see proposed_guided_devicegraph
    def propose_guided_devicegraph(devicegraph, drives)
      devicegraph = clean_graph(devicegraph, drives, [])
      begin
        guided_devicegraph_for_target(devicegraph, drives, :desired)
      rescue Error
        guided_devicegraph_for_target(devicegraph, drives, :min)
      end
    end

    # Calculates list of planned devices
    #
    # If the list does not contain any partition, then it follows the same
    # approach as the guided proposal
    #
    # @param devicegraph [Devicegraph]                 Starting point
    # @param drives      [Proposal::AutoinstDrivesMap] Devices map from an AutoYaST profile
    # @return [Planned::DevicesCollection] Devices to add
    def plan_devices(devicegraph, drives)
      planner = Proposal::AutoinstDevicesPlanner.new(devicegraph, issues_list)
      planner.planned_devices(drives)
    end

    # Clean a devicegraph according to an AutoYaST drives map
    #
    # @param devicegraph     [Devicegraph]       Starting point
    # @param drives          [AutoinstDrivesMap] Devices map from an AutoYaST profile
    # @param planned_devices [<Planned::DevicesCollection>] Planned devices
    # @return [Devicegraph] Clean devicegraph
    #
    # @see Y2Storage::Proposal::AutoinstSpaceMaker
    def clean_graph(devicegraph, drives, planned_devices)
      space_maker = Proposal::AutoinstSpaceMaker.new(disk_analyzer, issues_list)
      space_maker.cleaned_devicegraph(devicegraph, drives, planned_devices)
    end

    # Creates a devicegraph using the same approach as guided partitioning
    #
    # @param devicegraph [Devicegraph]       Starting point
    # @param drives      [AutoinstDrivesMap] Devices map from an AutoYaST profile
    # @param target      [Symbol] :desired means the sizes of the partitions should
    #   be the ideal ones, :min for generating the smallest functional partitions
    # @return [Devicegraph] Copy of devicegraph containing the planned devices
    def guided_devicegraph_for_target(devicegraph, drives, target)
      guided_settings = proposal_settings_for_disks(drives)
      guided_planner = Proposal::DevicesPlanner.new(guided_settings, devicegraph)
      @planned_devices = Planned::DevicesCollection.new(guided_planner.planned_devices(target))
      result = create_devices(devicegraph, @planned_devices, drives.disk_names)
      result.devicegraph
    end

    # Creates planned devices on a given devicegraph
    #
    # If adding boot devices makes impossible to create the rest of devices,
    # it will try again without them. In such a case, it will register an
    # issue.
    #
    # As a side effect, it updates the planned devices list if needed.
    #
    # @param devicegraph     [Devicegraph]                Starting point
    # @param planned_devices [Planned::DevicesCollection] Devices to add
    # @param disk_names      [Array<String>]              Names of the disks to consider
    # @return [Devicegraph] Copy of devicegraph containing the planned devices
    def create_devices(devicegraph, planned_devices, disk_names)
      boot_parts = boot_devices(devicegraph, @planned_devices)
      devices_creator = Proposal::AutoinstDevicesCreator.new(devicegraph)
      begin
        planned_with_boot = planned_devices.prepend(boot_parts)
        result = devices_creator.populated_devicegraph(planned_with_boot, disk_names)
        @planned_devices = planned_with_boot
      rescue Y2Storage::NoDiskSpaceError
        raise if boot_parts.empty?
        result = devices_creator.populated_devicegraph(planned_devices, disk_names)
        issues_list.add(:could_not_create_boot)
      end
      result
    end

    # Add shrinked devices to the issues list
    #
    # @param result [Proposal::CreatorResult] Result after creating the planned devices
    def add_reduced_devices_issues(result)
      if !result.shrinked_partitions.empty?
        issues_list.add(:shrinked_planned_devices, result.shrinked_partitions)
      end

      # rubocop:disable Style/GuardClause
      if !result.shrinked_lvs.empty?
        issues_list.add(:shrinked_planned_devices, result.shrinked_lvs)
      end
    end

    # Returns the product's proposal settings for a given set of disks
    #
    # @param drives [Proposal::AutoinstDrivesMap] Devices map from an AutoYaST profile
    # @return [ProposalSettings] Proposal settings considering only the given disks
    #
    # @see Y2Storage::BlkDevice#name
    def proposal_settings_for_disks(drives)
      settings = ProposalSettings.new_for_current_product
      settings.use_snapshots = drives.use_snapshots?
      settings.candidate_devices = drives.disk_names
      settings
    end
  end
end
