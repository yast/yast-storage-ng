require "yast"
require "storage/proposal/exceptions"
require "storage/proposal/settings"
require "storage/proposal/refined_devicegraph"
require "storage/proposal/volumes_generator"
require "storage/proposal/devicegraph_generator"

module Yast
  module Storage
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
      # Settings used to calculate the proposal. They cannot be altered after
      # calculating the proposal
      # @return [Proposal::Settings]
      attr_reader :settings
      # Planned volumes calculated by the proposal, nil if the proposal has not
      # been calculated yet
      # @return [PlannedVolumeCollection]
      attr_reader :volumes
      # Proposed layout of devices, nil if the proposal has not been
      # calculated yet
      # @return [::Storage::Devicegraph]
      attr_reader :devices

      def initialize(settings: nil)
        @settings = settings || Settings.new
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
        raise UnexceptedCallError if proposed?
        settings.freeze
        @proposed = true
        @volumes = volumes_generator.volumes
        @devices = devicegraph_generator.devicegraph(volumes)
      end

    protected

      def volumes_generator
        @volumes_generator ||= VolumesGenerator.new(settings)
      end

      def devicegraph_generator
        @devicegraph_generator ||= DevicegraphGenerator.new(settings)
      end
    end
  end
end
