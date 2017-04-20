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
require "y2storage/proposal/exceptions"
require "y2storage/proposal/volumes_generator"
require "y2storage/proposal/devicegraph_generator"

module Y2Storage
  # Class to calculate a storage proposal to install the system
  #
  # @example
  #   proposal = Storage::Proposal.new
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
  class Proposal
    include Yast::Logger

    # Settings used to calculate the proposal. They cannot be altered after
    # calculating the proposal
    # @return [ProposalSettings]
    attr_reader :settings
    # Planned volumes calculated by the proposal, nil if the proposal has not
    # been calculated yet
    # @return [PlannedVolumeList]
    attr_reader :volumes
    # Proposed layout of devices, nil if the proposal has not been
    # calculated yet
    # @return [Devicegraph]
    attr_reader :devices

    def initialize(settings: nil)
      @settings = settings || ProposalSettings.new
      @proposed = false
    end

    # Checks whether the proposal has already being calculated
    # @return [Boolean]
    def proposed?
      @proposed
    end

    # Calculates the proposal
    #
    # @raise [Proposal::UnexpectedCallError] if called more than once
    # @raise [Proposal::NoDiskSpaceError] if there is no enough space to
    #           perform the installation
    def propose
      raise UnexpectedCallError if proposed?
      settings.freeze
      @proposed = true

      # FIXME: The current implementation, tries :desired and then :min for
      # every root disk. It would probably make more sense to try first :desired
      # for all possible root disks and then do the same with :min.
      exception = nil
      candidate_roots.each do |disk_name|
        populated_settings.root_device = disk_name
        exception = nil

        begin
          @volumes = volumes_list
          @devices = devicegraph(@volumes)
        rescue Error => error
          log.info "Failed to make a proposal using root device #{disk_name}: #{error.message}"
          exception = error
        end

        break unless exception
      end

      raise exception if exception
    end

  protected

    # @return [PlannedVolumesList]
    def volumes_list
      generator = VolumesGenerator.new(populated_settings, initial_graph)
      generator.volumes
    end

    # Devicegraph resulting of accommodating some volumes in the initial
    # devicegraph
    #
    # @param volumes [PlannedVolumesList] list of volumes to accomodate
    # @return [Devicegraph]
    def devicegraph(volumes)
      generator = DevicegraphGenerator.new(populated_settings)
      generator.devicegraph(volumes, initial_graph, disk_analyzer)
    end

    # Disk analyzer used to analyze the initial devigraph
    #
    # @return [DiskAnalyzer]
    def disk_analyzer
      @disk_analyzer ||= DiskAnalyzer.new(initial_graph)
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
      candidate_disks = initial_graph.disks.select { |d| disk_names.include?(d.name) }
      candidate_disks = candidate_disks.sort_by(&:size).reverse
      candidate_disks.map(&:name)
    end
  end
end
