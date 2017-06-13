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
require "y2storage/skip_list"

module Y2Storage
  # Class to calculate a storage proposal for autoinstallation
  #
  # @example Example
  #   profile = Yast::Profile.current["partitioning"]
  #   proposal = Y2Storage::AutoInstProposal.new(partitioning)
  #   proposal.proposed?            # => false
  #   proposal.proposed_devicegraph # => nil
  #   proposal.planned_devices      # => nil
  #
  #   proposal.propose              # => Performs the calculation
  #
  #   proposal.proposed?            # => true
  #   proposal.proposed_devicegraph # => Proposed layout
  class AutoInstProposal
    include Yast::Logger

    # @return [Hash] Partitioning layout from an AutoYaST profile
    attr_reader :partitioning

    # @return [Devicegraph] Initial device graph
    attr_reader :initial_devicegraph

    # Planned devices calculated by the proposal, nil if the proposal has not
    # been calculated yet
    #
    # @return [Array<Planned::Device>]
    attr_reader :planned_devices

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
    # @param disk_analyzer [DiskAnalyzer] if nil, a new one will be created
    #   based in the initial devicegraph
    def initialize(partitioning: [], devicegraph: nil, disk_analyzer: nil)
      @partitioning = partitioning
      @initial_devicegraph = devicegraph
      @disk_analyzer = disk_analyzer
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
      devicegraph = space_maker.provide_space(initial_devicegraph, drives)

      @planned_devices = plan_devices(devicegraph, drives)

      devices_creator = Proposal::AutoinstDevicesCreator.new(devicegraph)
      @proposed_devicegraph = devices_creator.devicegraph(@planned_devices, drives.disk_names)
      @proposed = true

      nil
    end

  protected

    # Calculates list of planned devices
    #
    # If the list does not contain any partition, then it follows
    # the same approach than the guided proposal
    #
    # @param devicegraph [Devicegraph]
    # @param drives [Proposal::AutoinstDrivesMap]
    def plan_devices(devicegraph, drives)
      planner = Proposal::AutoinstDevicesPlanner.new(devicegraph)
      planner.planned_devices(drives)
    rescue Error
      log.info "No partitions were specified. Falling back to guided setup planning."
      guided_settings = ProposalSettings.new_for_current_product
      guided_settings.candidate_devices = drives.disk_names
      guided_planner = Proposal::PlannedDevicesGenerator.new(guided_settings, devicegraph)
      guided_planner.planned_devices
    end

    # Disk analyzer used to analyze the initial devicegraph
    #
    # @return [DiskAnalyzer]
    def disk_analyzer
      @disk_analyzer ||= DiskAnalyzer.new(initial_devicegraph)
    end
  end
end
