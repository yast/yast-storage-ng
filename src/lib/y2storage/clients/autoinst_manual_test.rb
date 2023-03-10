# Copyright (c) [2021] SUSE LLC
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
require "y2storage"
require "installation/proposal_store"
require "installation/proposal_runner"

module Y2Storage
  # Helper class to display only the partitioning AutoYaST proposal
  class TestProposalStore < Installation::ProposalStore
    # @return [Array<String>] proposal names in execution order, including
    #    the "_proposal" suffix
    def proposal_names
      ["partitions_proposal"]
    end

    # @return [Array<String>] single list of modules presentation order
    def presentation_order
      proposal_names
    end
  end

  module Clients
    # Simple client to compute and display the AutoYaST storage proposal
    class AutoinstManualTest
      # Constructor
      def initialize
        Yast.import "AutoinstStorage"
        Yast.import "AutoinstConfig"
        Yast.import "Wizard"
      end

      # Computes the AutoYaST partitioning proposal based on the current profile and opens a dialog
      # to display the result
      #
      # @return [Symbol]
      def run
        Yast::AutoinstStorage.Import(Yast::Profile.current["partitioning"])
        display_autoinst_proposal
      end

      private

      # @see #run
      def display_autoinst_proposal
        Yast::AutoinstConfig.Confirm = true
        Yast::Wizard.OpenNextBackDialog
        begin
          ret = Installation::ProposalRunner.new(TestProposalStore).run
        ensure
          Yast::Wizard.CloseDialog
        end

        ret
      end
    end
  end
end
