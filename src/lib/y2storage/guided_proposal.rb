# encoding: utf-8

# Copyright (c) [2016-2017] SUSE LLC
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
require "y2storage/proposal"

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
  #
  class GuidedProposal < Proposal::Base
    # Settings used to calculate the proposal. They cannot be altered after
    # calculating the proposal
    # @return [ProposalSettings]
    attr_reader :settings

    class << self
      # Calculates the initial proposal
      #
      # If a proposal is not possible by honoring current settings, other settings
      # are tried. For example, a proposal without separate home or without snapshots
      # will be calculated. The settings modifications depends on the strategy used for
      # generating the initial proposal.
      #
      # @see GuidedProposal#initialize
      # @see Proposal::InitialStragegies::Legacy#initial_proposal
      # @see Proposal::InitialStragegies::Ng#initial_proposal
      #
      # @param settings [ProposalSettings] if nil, default settings will be used
      # @param devicegraph [Devicegraph] starting point. If nil, the probed
      #   devicegraph will be used
      # @param disk_analyzer [DiskAnalyzer] if nil, a new one will be created
      #   based on the initial devicegraph.
      #
      # @return [GuidedProposal]
      def initial(settings: nil, devicegraph: nil, disk_analyzer: nil)
        settings ||= ProposalSettings.new_for_current_product

        strategy = initial_strategy(settings)

        strategy.new.initial_proposal(
          settings:      settings,
          devicegraph:   devicegraph,
          disk_analyzer: disk_analyzer
        )
      end

    private

      # Stragegy to create an initial proposal
      #
      # The strategy depends on the settings format.
      #
      # @see ProposalSettings#format
      #
      # @param settings [ProposalSettings]
      # @return [Proposal::InitialStrategies::Legacy, Proposal::InitialStrategies::Ng]
      def initial_strategy(settings)
        if settings.format == ProposalSettings::LEGACY_FORMAT
          Proposal::InitialStrategies::Legacy
        else
          Proposal::InitialStrategies::Ng
        end
      end
    end

    # Constructor
    #
    # @param settings [ProposalSettings] if nil, default settings will be used
    # @param devicegraph [Devicegraph] starting point. If nil, the probed
    #   devicegraph will be used
    # @param disk_analyzer [DiskAnalyzer] by default, the method will create a new one
    #   based on the initial {devicegraph} or will use the one in {StorageManager} if
    #   starting from probed (i.e. {devicegraph} argument is also missing)
    def initialize(settings: nil, devicegraph: nil, disk_analyzer: nil)
      super(devicegraph: devicegraph, disk_analyzer: disk_analyzer)
      @settings = settings || ProposalSettings.new_for_current_product
    end

  private

    # Calculates the proposal
    #
    # @raise [Error, NoDiskSpaceError] if there is no enough space to perform the installation
    def calculate_proposal
      settings.freeze

      exception = nil
      saved_root_device = populated_settings.root_device

      groups = group_candidate_devices
      target_sizes.product(groups).each do |target, devices|
        # reset root_device, else #candidate_roots will just use it
        populated_settings.root_device = saved_root_device
        populated_settings.candidate_devices = devices

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

      raise exception || NoDiskSpaceError.new("No usable disks detected")
    end

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
      device_names = populated_settings.candidate_devices
      devices = device_names.map { |n| devicegraph.find_by_name(n) }
      devices.select { |d| d.partition_table && d.partitions.empty? }
    end

    # Returns the target sizes to make the proposal
    #
    # @return [Array<Symbol>]
    def target_sizes
      [:desired, :min]
    end

    # Settings used by each attempt of proposal
    #
    # A copy of original settings, which is intended to be populated during the process of making a
    # proposal. E.g, setting a value that was not given, such as the candidate devices or root
    # device.
    #
    # @return [ProposalSettings]
    def populated_settings
      @populated_settings ||= settings.dup
    end

    # Candidate devices grouped for different proposal attempts
    #
    # When some candidate devices are indicated in the settings, the proposal is tried with all of
    # them. However, when no candidate devices are given, different attempts should be done using
    # different sets of candidate devices. First, each available device is used lonely to make the
    # proposal, and if no proposal was possible with any individual disk, a last attempt is done by
    # using all available devices as candidate disks.
    #
    # @example
    #
    #   settings.candidate_devices #=> ["/dev/sda", "/dev/sdb"]
    #   settings.group_candidate_devices #=> [["/dev/sda", "/dev/sdb"]]
    #
    #   settings.candidate_devices #=> nil
    #   settings.group_candidate_devices #=> [["/dev/sda"], ["/dev/sdb"], ["/dev/sda", "/dev/sdb"]]
    #
    # @return [Array<String>]
    def group_candidate_devices
      return [settings.candidate_devices] if settings.candidate_devices

      candidates = disk_analyzer.candidate_disks.map(&:name)
      candidates.zip.append(candidates).uniq
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
      candidate_disks = initial_devicegraph.disk_devices.select { |d| disk_names.include?(d.name) }
      candidate_disks = candidate_disks.sort_by(&:size).reverse
      candidate_disks.map(&:name)
    end
  end
end
