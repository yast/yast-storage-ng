# Copyright (c) [2016-2018] SUSE LLC
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
require "y2storage/proposal"
require "y2storage/proposal_settings"
require "y2storage/exceptions"

module Y2Storage
  # Class to calculate a storage proposal to install the system
  #
  # @example
  #   proposal = Y2Storage::GuidedProposal.new
  #   proposal.settings.use_separate_home = true
  #   proposal.proposed?                          # => false
  #   proposal.devices                            # => nil
  #   proposal.planned_devices                    # => nil
  #
  #   proposal.propose                            # Performs the calculation
  #
  #   proposal.proposed?                          # => true
  #   proposal.devices                            # => Proposed layout
  #   proposal.settings.use_separate_home = false # raises RuntimeError
  class GuidedProposal < Proposal::Base
    # @overload settings
    #
    #   Settings for calculating the proposal.
    #
    #   @note The settings cannot be modified once the proposal has been calculated
    #
    #   @return [ProposalSettings]
    attr_reader :settings

    class << self
      # Calculates the initial proposal
      #
      # If a proposal is not possible by honoring current settings, other settings
      # are tried. For example, a proposal without separate home or without snapshots
      # will be calculated.
      #
      # @see InitialGuidedProposal
      # @see #initialize
      #
      # @param settings [ProposalSettings]
      # @param devicegraph [Devicegraph]
      # @param disk_analyzer [DiskAnalyzer]
      #
      # @return [InitialGuidedProposal]
      def initial(settings: nil, devicegraph: nil, disk_analyzer: nil)
        proposal = InitialGuidedProposal.new(
          settings:      settings,
          devicegraph:   devicegraph,
          disk_analyzer: disk_analyzer
        )

        proposal.propose
        proposal
      rescue Y2Storage::Error
        log.error("Initial proposal failed")
        proposal
      end
    end

    # Constructor
    #
    # @param settings [ProposalSettings] if nil, default settings will be used
    # @param devicegraph [Devicegraph] starting point. If nil, the probed devicegraph
    #   will be used.
    # @param disk_analyzer [DiskAnalyzer] by default, the method will create a new one
    #   based on the initial {devicegraph} or will use the one in {StorageManager} if
    #   starting from probed (i.e. {devicegraph} argument is also missing).
    def initialize(settings: nil, devicegraph: nil, disk_analyzer: nil)
      super(devicegraph: devicegraph, disk_analyzer: disk_analyzer)

      @settings = settings || ProposalSettings.new_for_current_product
    end

    private

    # @return [ProposalSettings]
    attr_writer :settings

    # @return [Proposal::SpaceMaker]
    attr_writer :space_maker

    # Calculates the proposal
    #
    # @see #try_proposal
    #
    # @raise [Error, NoDiskSpaceError] if there is no enough space to perform the installation
    #
    # @return [true]
    def calculate_proposal
      try_proposal
    ensure
      settings.freeze
    end

    # Tries to perform a proposal
    #
    # Settings might be completed with default values for candidate devices and root device.
    #
    # This method is intended to be redefined for derived classes, see {InitialGuidedProposal}.
    #
    # @raise [Error, NoDiskSpaceError] if it was not possible to calculate the proposal
    #
    # @return [true]
    def try_proposal
      complete_settings

      try_with_each_target_size
    end

    # Helper method to do a proposal attempt for each possible target size
    #
    # @see #target_sizes
    #
    # @raise [Error, NoDiskSpaceError] if it was not possible to calculate the proposal
    #
    # @return [true]
    def try_with_each_target_size
      error = default_proposal_error

      target_sizes.each do |target_size|

        log.info "Trying to make a proposal with target size: #{target_size}"

        @planned_devices = planned_devices_list(target_size)
        @devices = devicegraph(@planned_devices)
        return true
      rescue Error => e
        log.info "Failed to make a proposal with target size: #{target_size}"
        log.info "Error: #{e.message}"
        next

      end

      raise error
    end

    # All possible target sizes to make the proposal
    #
    # @return [Array<Symbol>]
    def target_sizes
      [:desired, :min]
    end

    # Default error when it is not possible to create a proposal
    #
    # @return [NoDiskSpaceError]
    def default_proposal_error
      NoDiskSpaceError.new("No usable disks detected")
    end

    # Completes the current settings with reasonable fallback values
    #
    # All settings coming from the control file have a fallback value, but there are some
    # settings that are only given by the user, for example: candidate_devices and
    # root_device. For those settings, some reasonable fallback values are given.
    def complete_settings
      settings.candidate_devices ||= candidate_devices
      settings.root_device ||= candidate_devices.first
    end

    # @return [Array<Planned::Device>]
    def planned_devices_list(target)
      generator = Proposal::DevicesPlanner.new(settings, clean_graph)
      generator.planned_devices(target)
    end

    # Devicegraph resulting of accommodating some planned devices in the
    # initial devicegraph
    #
    # @param planned_devices [Array<Planned::Device>] devices to accomodate
    # @return [Devicegraph]
    def devicegraph(planned_devices)
      generator = Proposal::DevicegraphGenerator.new(settings)
      generator.devicegraph(planned_devices, clean_graph, space_maker)
    end

    def space_maker
      @space_maker ||= Proposal::SpaceMaker.new(disk_analyzer, settings)
    end

    # Copy of #initial_devicegraph without all the partitions that must be wiped out
    # according to the settings. Empty partition tables are deleted from candidate
    # devices.
    #
    # @return [Y2Storage::Devicegraph]
    def clean_graph
      return @clean_graph if @clean_graph

      new_devicegraph = initial_devicegraph.dup

      # TODO: remember the list of affected devices so we can restore their partition tables at
      # the end of the process for those devices that were not used (as soon as libstorage-ng
      # allows us to copy sub-graphs).
      remove_empty_partition_tables(new_devicegraph)
      @clean_graph = space_maker.delete_unwanted_partitions(new_devicegraph)
    end

    # Removes partition tables from candidate devices with empty partition table
    #
    # @note The devicegraph is modified.
    #
    # @param devicegraph [Y2Storage::Devicegraph]
    # @return [Array<Integer>] sid of devices where partition table was deleted from
    def remove_empty_partition_tables(devicegraph)
      devices = candidate_devices_with_empty_partition_table(devicegraph)
      devices.each(&:delete_partition_table)
      devices.map(&:sid)
    end

    # All candidate devices with an empty partition table
    #
    # @param devicegraph [Y2Storage::Devicegraph]
    # @return [Array<Y2Storage::BlkDevice>]
    def candidate_devices_with_empty_partition_table(devicegraph)
      device_names = settings.candidate_devices
      devices = device_names.map { |n| devicegraph.find_by_name(n) }
      devices.select { |d| d.partition_table && d.partitions.empty? }
    end

    # Candidate devices to make a proposal
    #
    # The candidate devices are calculated when current settings do not contain any
    # candidate device. In that case, the possible candidate devices are sorted, placing
    # USB devices at the end.
    #
    # @return [Array<String>] e.g. ["/dev/sda", "/dev/sdc"]
    def candidate_devices
      return settings.candidate_devices unless settings.candidate_devices.nil?

      # NOTE: sort_by it is not being used here because "the result is not guaranteed to be stable"
      # see https://ruby-doc.org/core-2.5.0/Enumerable.html#method-i-sort_by
      # In addition, a partition makes more sense here since we only are "grouping" available disks
      # in two groups and moving one of them to the end.
      candidates = disk_analyzer.candidate_disks
      candidates = candidates.partition { |d| d.respond_to?(:usb?) && !d.usb? }.flatten
      candidates.map(&:name)
    end
  end
end
