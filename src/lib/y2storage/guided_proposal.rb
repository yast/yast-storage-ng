# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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
require "y2storage/storage_manager"
require "y2storage/disk_analyzer"
require "y2storage/exceptions"
require "y2storage/proposal"

module Y2Storage
  # Class to calculate a storage proposal to install the system
  #
  # @example
  #   proposal = Storage::GuidedProposal.new
  #   proposal.settings.use_separate_home = true
  #   proposal.proposed? # => false
  #   proposal.devices   # => nil
  #
  #   proposal.propose   # Performs the calculation
  #
  #   proposal.proposed? # => true
  #   proposal.devices   # Proposed layout
  #   proposal.settings.use_separate_home = false # raises RuntimeError
  #
  class GuidedProposal
    include Yast::Logger

    # Settings used to calculate the proposal. They cannot be altered after
    # calculating the proposal
    # @return [ProposalSettings]
    attr_reader :settings
    # Planned devices calculated by the proposal, nil if the proposal has not
    # been calculated yet
    # @return [Array<Planned::Device>]
    attr_reader :planned_devices
    # Proposed layout of devices, nil if the proposal has not been
    # calculated yet
    # @return [Devicegraph]
    attr_reader :devices

    class << self
      # Calculates the initial proposal
      #
      # If a proposal is not possible by honoring current settings, other settings
      # are tried. For example, a proposal without separate home or without snapshots
      # will be calculated.
      #
      # @see GuidedProposal#initialize
      #
      # @param settings [ProposalSettings] if nil, default settings will be used
      # @param devicegraph [Devicegraph] starting point. If nil, the probed
      #   devicegraph will be used
      # @param disk_analyzer [DiskAnalyzer] if nil, a new one will be created
      #   based on the initial devicegraph.
      #
      # @return [GuidedProposal]
      def initial(settings: nil, devicegraph: nil, disk_analyzer: nil)
        # Try proposal with initial settings
        current_settings = settings || ProposalSettings.new_for_current_product
        log.info("Trying proposal with initial settings: #{current_settings}")
        proposal = try_proposal(current_settings.dup, devicegraph, disk_analyzer)

        # Try proposal without home
        if proposal.failed? && current_settings.use_separate_home
          current_settings.use_separate_home = false
          log.info("Trying proposal without home: #{current_settings}")
          proposal = try_proposal(current_settings.dup, devicegraph, disk_analyzer)
        end

        # Try proposal without snapshots
        if proposal.failed? && current_settings.snapshots_active?
          current_settings.use_snapshots = false
          log.info("Trying proposal without home neither snapshots: #{current_settings}")
          proposal = try_proposal(current_settings.dup, devicegraph, disk_analyzer)
        end

        proposal
      end

    private

      # Try a proposal with specific settings. Always returns the proposal, even
      # when it is not possible to make a valid one. In that case, the resulting
      # proposal will not have devices.
      #
      # @return [GuidedProposal]
      def try_proposal(settings, devicegraph, disk_analyzer)
        proposal = GuidedProposal.new(
          settings:      settings,
          devicegraph:   devicegraph,
          disk_analyzer: disk_analyzer
        )
        proposal.propose
        proposal
      rescue Y2Storage::Error => e
        log.error("Proposal failed: #{e.inspect}")
        proposal
      end
    end

    # @param settings [ProposalSettings] if nil, default settings will be used
    # @param devicegraph [Devicegraph] starting point. If nil, the probed
    #   devicegraph will be used
    # @param disk_analyzer [DiskAnalyzer] if nil, a new one will be created
    #   based on the initial devicegraph
    def initialize(settings: nil, devicegraph: nil, disk_analyzer: nil)
      @settings = settings || ProposalSettings.new_for_current_product
      @proposed = false
      if devicegraph.nil?
        @initial_graph = StorageManager.instance.y2storage_probed
        @disk_analyzer = StorageManager.instance.probed_disk_analyzer
      else
        @initial_graph = devicegraph
        @disk_analyzer = disk_analyzer
      end
    end

    # Checks whether the proposal has already being calculated
    # @return [Boolean]
    def proposed?
      @proposed
    end

    # Calculates the proposal
    #
    # @raise [UnexpectedCallError] if called more than once
    # @raise [NoDiskSpaceError] if there is no enough space to
    #           perform the installation
    def propose
      raise UnexpectedCallError if proposed?
      settings.freeze
      @proposed = true

      exception = nil
      [:desired, :min].each do |target|
        candidate_roots.each do |disk_name|
          log.info "Trying to make a proposal with target #{target} and root #{disk_name}"

          populated_settings.root_device = disk_name
          exception = nil

          begin
            @planned_devices = planned_devices_list(target)
            @devices = devicegraph(@planned_devices)
          rescue Error => error
            log.info "Failed to make a proposal using root device #{disk_name}: #{error.message}"
            exception = error
          end

          return true unless exception
        end
      end

      raise exception
    end

    # A proposal is failed when it has not devices after being proposed
    #
    # @return [Boolean] true if proposed and has not devices; false otherwise
    def failed?
      proposed? && devices.nil?
    end

  protected

    # @return [Array<Planned::Device>]
    def planned_devices_list(target)
      generator = Proposal::DevicesPlanner.new(populated_settings, clean_graph)
      generator.planned_devices(target)
    end

    # Devicegraph resulting of accommodating some planned devices in the
    # initial devicegraph
    #
    # @param planned_devices [Array<Planned::Device>] devices to accomodate
    # @return [Devicegraph]
    def devicegraph(planned_devices)
      generator = Proposal::DevicegraphGenerator.new(populated_settings)
      generator.devicegraph(planned_devices, clean_graph, space_maker)
    end

    def space_maker
      @space_maker ||= Proposal::SpaceMaker.new(disk_analyzer, populated_settings)
    end

    # Disk analyzer used to analyze the initial devicegraph
    #
    # @return [DiskAnalyzer]
    def disk_analyzer
      @disk_analyzer ||= DiskAnalyzer.new(initial_graph)
    end

    # Copy of #initial_graph without all the partitions that must be wiped out
    # according to the settings
    def clean_graph
      @clean_graph ||= space_maker.delete_unwanted_partitions(initial_graph)
    end

    def initial_graph
      @initial_graph ||= StorageManager.instance.y2storage_probed
    end

    # Copy of the original settings including some calculated and necessary
    # values (mainly candidate_devices), in case they were not present
    #
    # @return [ProposalSettings]
    def populated_settings
      return @populated_settings if @populated_settings

      populated = settings.dup
      populated.candidate_devices ||= disk_analyzer.candidate_disks.map(&:name)

      @populated_settings = populated
    end

    # Sorted list of disks to be tried as root_device.
    #
    # If the current settings already specify a root_device, the list will
    # contain only that one.
    #
    # Otherwise, it will contain all the candidate devices, sorted from bigger
    # to smaller disk size.
    #
    # @return [Array<String>] names of the chosen devices
    def candidate_roots
      return [populated_settings.root_device] if populated_settings.root_device

      disk_names = populated_settings.candidate_devices
      candidate_disks = initial_graph.disk_devices.select { |d| disk_names.include?(d.name) }
      candidate_disks = candidate_disks.sort_by(&:size).reverse
      candidate_disks.map(&:name)
    end
  end
end
