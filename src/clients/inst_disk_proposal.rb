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
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

require "yast"
require "y2storage"

Yast.import "UI"
Yast.import "Wizard"
Yast.import "HTML"

include Yast::I18n
include Yast::Logger

module Yast
  #
  # client to calculate the storage proposal during installation and provide
  # the user a summary of the storage proposal
  #
  class InstDiskProposalClient < Client
    using Y2Storage::Refinements::Devicegraph

    def main
      textdomain "storage"

      begin
        proposal = Y2Storage::Proposal.new(settings: settings)
        proposal.propose
        actiongraph = proposal.devices.actiongraph
        summary = summary(actiongraph)
      rescue Y2Storage::Proposal::Error
        # error message
        summary = HTML.Para(HTML.Colorize("No proposal possible.", "red"))
      end

      # Title for dialog
      title = _("Suggested Partitioning")

      contents = MarginBox(
        2, 1,
        VBox(
          MinHeight(8, RichText(summary))
        )
      )

      Wizard.SetContents(title, contents, "help", true, true)

      Wizard.UserInput

      return :next
    end

  protected

    def settings
      settings = Y2Storage::ProposalSettings.new
      settings.use_separate_home = true
      return settings
    end

    def summary(actiongraph)
      texts = actiongraph.commit_actions_as_strings.to_a
      return HTML.Para(HTML.List(texts))
    end
  end
end

Yast::InstDiskProposalClient.new.main
