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
require "y2storage/storage_manager"
require "y2storage/disk_analyzer"
require "y2storage/proposal"
require "y2storage/exceptions"

module Y2Storage
  # Class to calculate a storage proposal for autoinstallation
  #
  # @example Creating a proposal from the current AutoYaST profile
  #   partitioning = Yast::Profile.current["partitioning"]
  #   proposal = Y2Storage::AutoinstProposal.new(partitioning)
  #   proposal.proposed?            # => false
  #   proposal.proposed_devicegraph # => nil
  #   proposal.planned_devices      # => nil
  #
  #   proposal.propose              # => Performs the calculation
  #
  #   proposal.proposed?            # => true
  #   proposal.proposed_devicegraph # => Proposed layout
  class AutoinstProposal
    include Yast::Logger

    # @return [Hash] Partitioning layout from an AutoYaST profile
    attr_reader :partitioning

    # @return [Devicegraph] Initial devicegraph
    attr_reader :initial_devicegraph

    # Proposed layout of devices, nil if the proposal has not been
    # calculated yet
    # @return [Devicegraph]
    attr_reader :proposed_devicegraph

    alias_method :devices, :proposed_devicegraph

    # Constructor
    #
    # @param partitioning [Array<Hash>] Partitioning schema from an AutoYaST profile
    # @param devicegraph  [Devicegraph] starting point. If nil, then probed devicegraph
    #   will be used
    # @param disk_analyzer [DiskAnalyzer] by default, the method will create a new one
    #   based on the initial {devicegraph} or will use the one in {StorageManager} if
    #   starting from probed (i.e. {devicegraph} argument is also missing)
    def initialize(partitioning: [], devicegraph: nil, disk_analyzer: nil)
      @partitioning = AutoinstProfile::PartitioningSection.new_from_hashes(partitioning)
      @initial_devicegraph = devicegraph
      @disk_analyzer = disk_analyzer

      # Use probed devicegraph if no devicegraph is passed
      if @initial_devicegraph.nil?
        @initial_devicegraph = StorageManager.instance.y2storage_probed
        # Use cached disk analyzer for probed devicegraph is no disk analyzer is passed
        @disk_analyzer ||= StorageManager.instance.probed_disk_analyzer
      end
      # Create new disk analyzer when devicegraph is passed but not disk analyzer
      @disk_analyzer ||= DiskAnalyzer.new(@initial_devicegraph)

      @proposed = false
    end

    # Checks whether the proposal has already been calculated
    #
    # @return [Boolean]
    def proposed?
      @proposed
    end

    # Calculates the proposal
    #
    # @raise [UnexpectedCallError] if called more than once
    # @raise [NoDiskSpaceError] if there is no enough space to perform the installation
    def propose
      raise UnexpectedCallError if proposed?

      drives = Proposal::AutoinstDrivesMap.new(initial_devicegraph, partitioning)

      space_maker = Proposal::AutoinstSpaceMaker.new(disk_analyzer)
      devicegraph = space_maker.cleaned_devicegraph(initial_devicegraph, drives)

      @proposed_devicegraph = propose_devicegraph(devicegraph, drives)
      @proposed = true
    end

  protected

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
        planned_devices = plan_devices(devicegraph, drives)
        create_devices(devicegraph, planned_devices, drives.disk_names)
      else
        log.info "No partitions were specified. Falling back to guided setup planning."
        propose_guided_devicegraph(devicegraph, drives)
      end
    end

    # Finds a suitable devicegraph using the guided proposal approach
    #
    # If the :desired target fails, it will retry with the :min target.
    #
    # @param devicegraph [Devicegraph]       Starting point
    # @param drives      [AutoinstDrivesMap] Devices map from an AutoYaST profile
    # @return [Devicegraph] Proposed devicegraph using the guidede proposal approach
    #
    # @raise [Error] No suitable devicegraph was found
    # @see proposed_guided_devicegraph
    def propose_guided_devicegraph(devicegraph, drives)
      guided_devicegraph_for_target(devicegraph, drives, :desired)
    rescue Error
      guided_devicegraph_for_target(devicegraph, drives, :min)
    end

    # Calculates list of planned devices
    #
    # If the list does not contain any partition, then it follows the same
    # approach as the guided proposal
    #
    # @param devicegraph [Devicegraph]                 Starting point
    # @param drives      [Proposal::AutoinstDrivesMap] Devices map from an AutoYaST profile
    # @return [Array<Planned::Device>] Devices to add
    def plan_devices(devicegraph, drives)
      planner = Proposal::AutoinstDevicesPlanner.new(devicegraph)
      planner.planned_devices(drives)
    end

    # Creates a devicegraph using the same approach as guided partitioning
    #
    # @param devicegraph [Devicegraph]       Starting point
    # @param drives      [AutoinstDrivesMap] Devices map from an AutoYaST profile
    # @param target      [Symbol] :desired means the sizes of the partitions should
    #   be the ideal ones, :min for generating the smallest functional partitions
    # @return [Devicegraph] Copy of devicegraph containing the planned devices
    def guided_devicegraph_for_target(devicegraph, drives, target)
      guided_settings = proposal_settings_for_disks(drives.disk_names)
      guided_planner = Proposal::DevicesPlanner.new(guided_settings, devicegraph)
      planned_devices = guided_planner.planned_devices(target)
      create_devices(devicegraph, planned_devices, drives.disk_names)
    end

    # Creates planned devices on a given devicegraph
    #
    # @param devicegraph     [Devicegraph]            Starting point
    # @param planned_devices [Array<Planned::Device>] Devices to add
    # @param disk_names      [Array<String>]          Names of the disks to consider
    # @return [Devicegraph] Copy of devicegraph containing the planned devices
    def create_devices(devicegraph, planned_devices, disk_names)
      devices_creator = Proposal::AutoinstDevicesCreator.new(devicegraph)
      devices_creator.populated_devicegraph(planned_devices, disk_names)
    end

    # Returns the product's proposal settings for a given set of disks
    #
    # @param disk_names [Array<String>] Disks names to consider
    # @return [ProposalSettings] Proposal settings considering only the given disks
    #
    # @see Y2Storage::BlkDevice#name
    def proposal_settings_for_disks(disk_names)
      settings = ProposalSettings.new_for_current_product
      settings.candidate_devices = disk_names
      settings
    end

    # Disk analyzer used to analyze the initial devicegraph
    #
    # @return [DiskAnalyzer]
    def disk_analyzer
      @disk_analyzer ||= DiskAnalyzer.new(initial_devicegraph)
    end

    # Devicegraph used as starting point
    #
    # @return [Devicegraph] starting point. Probed devicegraph will be used if none was passed to
    #   the constructor.
    def initial_devicegraph
      @initial_devicegraph ||= Y2Storage::StorageManager.instance.probe
    end
  end
end
