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
        textdomain "storage-ng"
        propose!
      end

      def next_handler
        if devicegraph
          log.info "Setting the devicegraph as staging"
          Y2Storage::StorageManager.instance.copy_to_staging(devicegraph)
          super
        else
          confirm = Yast::Popup.ContinueCancel(
            _("Continue installation without a valid proposal?")
          )
          super if confirm
        end
      end

    protected

      # Desired devicegraph
      attr_accessor :devicegraph

      # For the time being, it always returns the same proposal settings.
      # To be connected to control.xml and the UI in the future
      #
      # @return [Y2Storage::ProposalSettings]
      def settings
        settings = Y2Storage::ProposalSettings.new
        settings.use_separate_home = true
        settings
      end

      # Calculates the desired devicegraph using the storage proposal.
      # Sets the devigraph to nil if something went wrong
      def propose!
        proposal = Y2Storage::Proposal.new(settings: settings)
        proposal.propose
        self.devicegraph = proposal.devices
      rescue Y2Storage::Proposal::Error
        log.error("generating proposal failed")
        self.devicegraph = nil
      end

      # HTML-formatted text to display in the dialog
      #
      # If a proposal could be calculated, it returns a text representation of
      # the actiongraph. Otherwise it returns an error message.
      #
      # @return [String]
      def summary
        if devicegraph
          actiongraph = devicegraph.actiongraph
          texts = actiongraph.commit_actions_as_strings.to_a
          Yast::HTML.Para(Yast::HTML.List(texts))
        else
          Yast::HTML.Para(Yast::HTML.Colorize(_("No proposal possible."), "red"))
        end
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
