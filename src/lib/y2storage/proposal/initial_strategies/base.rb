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
require "y2storage/guided_proposal"
require "y2storage/exceptions"
require "abstract_method"

module Y2Storage
  module Proposal
    module InitialStrategies
      # Base class for the strategies used to calculate an initial proposal to install the system
      class Base
        include Yast::Logger

        # @!method initial_proposal(settings, devicegraph, diskanalizer)
        #   Calculates the initial proposal. It must be defined by derived classes.
        #
        #   @see GuidedProposal#initialize
        #
        #   @param settings [ProposalSettings] if nil, default settings will be used
        #   @param devicegraph [Devicegraph] starting point. If nil, the probed
        #     devicegraph will be used
        #   @param disk_analyzer [DiskAnalyzer] if nil, a new one will be created
        #     based on the initial devicegraph.
        #
        #   @return [GuidedProposal]
        abstract_method :initial_proposal

      private

        # Try a proposal with specific settings. Always returns the proposal, even
        # when it is not possible to make a valid one. In that case, the resulting
        # proposal will not have devices.
        #
        # @param settings [ProposalSettings] if nil, default settings will be used
        # @param devicegraph [Devicegraph] starting point. If nil, the probed
        #   devicegraph will be used
        # @param disk_analyzer [DiskAnalyzer] if nil, a new one will be created
        #   based on the initial devicegraph.
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
    end
  end
end
