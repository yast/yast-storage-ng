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

module Y2Storage
  module Proposal
    # Class to calculate a storage proposal
    #
    # @note This is a base class. To really perform a proposal, see classes
    #   {Y2Storage::GuidedProposal} and {Y2Storage::AutoinstProposal}
    class Base
      include Yast::Logger

      # Planned devices calculated by the proposal, nil if the proposal has not
      # been calculated yet
      # @return [Array<Planned::Device>]
      attr_reader :planned_devices
      # Proposed layout of devices, nil if the proposal has not been calculated yet
      # @return [Devicegraph]
      attr_reader :devices

      # Constructor
      #
      # @param devicegraph [Devicegraph] starting point. If nil, the probed
      #   devicegraph will be used
      # @param disk_analyzer [DiskAnalyzer] by default,  a new one will be created
      #   based on the initial {devicegraph} or it will use the one in {StorageManager}
      #   if starting from probed (i.e. {devicegraph} argument is also missing)
      def initialize(devicegraph: nil, disk_analyzer: nil)
        @proposed = false
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
      end

      # Calculates the proposal
      # @note It should be defined by derived classes
      #
      # @raise [NotImplementedError]
      def propose
        raise NotImplementedError,
          "Subclasses of #{Module.nesting.first} must override #{__method__}"
      end

      # Checks whether the proposal has already being calculated
      #
      # @return [Boolean]
      def proposed?
        @proposed
      end

      # A proposal is failed when it has not devices after being proposed
      #
      # @return [Boolean] true if proposed and has not devices; false otherwise
      def failed?
        proposed? && devices.nil?
      end

    private

      # Disk analyzer used to analyze the initial devicegraph
      # @return [DiskAnalyzer]
      attr_reader :disk_analyzer
      # @return [Devicegraph]
      attr_reader :initial_devicegraph
    end
  end
end
