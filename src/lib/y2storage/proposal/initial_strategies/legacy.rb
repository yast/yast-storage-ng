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

require "y2storage/proposal/initial_strategies/base"

module Y2Storage
  module Proposal
    module InitialStrategies
      # Class to calculate an initial proposal to install the system when the
      # proposal settings has legacy format
      class Legacy < Base
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
        def initial_proposal(settings: nil, devicegraph: nil, disk_analyzer: nil)
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
      end
    end
  end
end
