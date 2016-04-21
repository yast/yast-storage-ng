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
require "storage/storage_manager"
require "storage/disk_analyzer"
require "storage/proposal/exceptions"
require "storage/proposal/settings"
require "storage/proposal/volumes_generator"
require "storage/proposal/devicegraph_generator"
require "storage/refinements/devicegraph_lists"

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
      using Refinements::DevicegraphLists

      # Settings used to calculate the proposal. They cannot be altered after
      # calculating the proposal
      # @return [Proposal::Settings]
      attr_reader :settings
      # Planned volumes calculated by the proposal, nil if the proposal has not
      # been calculated yet
      # @return [PlannedVolumeList]
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
        @volumes = volumes_list(:all, populated_settings)
        @devices = devicegraph(@volumes, populated_settings)
      end

    protected

      # @param set [#to_s] List of volumes to generate, :all or :base
      # @param settings [Proposal::Settings]
      # @return [PlannedVolumesList]
      def volumes_list(set, settings)
        generator = VolumesGenerator.new(settings, disk_analyzer)
        generator.send(:"#{set}_volumes")
      end

      # Devicegraph resulting of accommodating some volumes in the initial
      # devicegraph
      #
      # @param volumes [PlannedVolumesList] list of volumes to accomodate
      # @param settings [Proposal::Settings]
      # @return [::Storage::Devicegraph]
      def devicegraph(volumes, settings)
        generator = DevicegraphGenerator.new(settings)
        generator.devicegraph(volumes, initial_graph, disk_analyzer)
      end

      # Disk analyzer used to analyze the initial devigraph
      #
      # @return [DiskAnalyzer]
      def disk_analyzer
        @disk_analyzer ||= begin
          analyzer = DiskAnalyzer.new
          analyzer.analyze(initial_graph)
          analyzer
        end
      end

      def initial_graph
        @initial_graph ||= StorageManager.instance.probed
      end

      # Copy of the original settings including some calculated and necessary
      # values (like candidate_devices or root_device), in case they were not
      # present
      #
      # @return [Proposal::Settings]
      def populated_settings
        return @populated_settings if @populated_settings

        populated = settings.dup
        populated.candidate_devices ||= disk_analyzer.candidate_disks
        populated.root_device ||= proposed_root_device(populated)

        @populated_settings = populated
      end

      # Proposes a value for settings.root_devices if none was provided
      #
      # It assumes settings.candidate_devices is already set.
      # It tries to allocate the base volumes using each candidate device
      # as root, returning the first for which that allocation is possible.
      #
      # @raise Proposal::NoSuitableDeviceError if the base volumes don't fit for
      # any root candidate
      #
      # @param settings [Proposal::Settings]
      # @return [String] name of the chosen device
      def proposed_root_device(settings)
        names = sorted_candidates(settings.candidate_devices)
        names.each do |disk_name|
          new_settings = settings.dup
          new_settings.root_device = disk_name
          begin
            volumes = volumes_list(:base, new_settings)
            devicegraph(volumes, new_settings)
            return disk_name
          rescue Proposal::Error
            next
          end
        end

        raise Proposal::NoSuitableDeviceError, "No room for base volumes in #{names}"
      end

      # Sorts a list of disk names from bigger to smaller disk size
      #
      # @param disk_names [Array<String>] unsorted list of names
      # @return [Array<String>] sorted list of names
      def sorted_candidates(disk_names)
        candidate_disks = initial_graph.disks.with(name: disk_names).to_a
        candidate_disks = candidate_disks.sort_by(&:size_k).reverse
        candidate_disks.map(&:name)
      end
    end
  end
end
