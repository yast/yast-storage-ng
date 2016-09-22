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
require "ui/installation_dialog"

Yast.import "HTML"

module Y2Storage
  module Dialogs
    # Calculates the storage proposal during installation and provides
    # the user a summary of the storage proposal
    class InstDiskProposal < ::UI::InstallationDialog
      # For Devicegraph#actiongraph
      using Y2Storage::Refinements::Devicegraph

      def initialize
        super
        textdomain "storage"
      end

    protected

      # For the time being, it always returns the same proposal settings.
      # To be connected to control.xml and the UI in the future
      #
      # @return [Y2Storage::ProposalSettings]
      def settings
        settings = Y2Storage::ProposalSettings.new
        settings.use_separate_home = true
        settings
      end

      # HTML-formatted text to display in the dialog
      #
      # @return [String]
      def summary
        formatted_actiongraph
      rescue Y2Storage::Proposal::Error
        log.error("generating proposal failed")
        # error message
        Yast::HTML.Para(Yast::HTML.Colorize(_("No proposal possible."), "red"))
      end

      # Calculates the proposal's actiongraph and returns its HTML-formatted
      # text representation
      #
      # @raise Y2Storage::Proposal::Error if the proposal cannot be calculated
      # @return [String]
      def formatted_actiongraph
        proposal = Y2Storage::Proposal.new(settings: settings)
        proposal.propose
        actiongraph = proposal.devices.actiongraph
        texts = actiongraph.commit_actions_as_strings.to_a
        Yast::HTML.Para(Yast::HTML.List(texts))
      end

      def dialog_title
        _("Suggested Partitioning")
      end

      def dialog_content
        MarginBox(
          2, 1,
          VBox(
            MinHeight(8, RichText(summary))
          )
        )
      end

      def help_text
        _(
          "<p>\n" \
          "Your hard disks have been checked. The partition setup\n" \
          "displayed is proposed for your hard drive.</p>"
        )
      end
    end
  end
end
