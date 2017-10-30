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
require "y2storage/actions_presenter"
require "ui/installation_dialog"

Yast.import "HTML"

module Y2Storage
  module Dialogs
    # Calculates the storage proposal during installation and provides
    # the user a summary of the storage proposal
    class Proposal < ::UI::InstallationDialog
      attr_reader :proposal
      attr_reader :devicegraph

      def initialize(proposal, devicegraph)
        log.info "Proposal dialog: start with #{proposal.inspect}"

        super()
        textdomain "storage"

        @proposal = proposal
        @devicegraph = devicegraph
        propose! if proposal && !proposal.proposed?
        actiongraph = @devicegraph ? @devicegraph.actiongraph : nil
        @actions_presenter = ActionsPresenter.new(actiongraph)
      end

      def next_handler
        if devicegraph
          log.info "Proposal dialog: return :next with #{proposal} and #{devicegraph}"
          super
        else
          Yast::Report.Error(_("Cannot continue"))
        end
      end

      def guided_handler
        finish_dialog(:guided)
      end

      def expert_from_proposal_handler
        finish_dialog(:expert_from_proposal)
      end

      def expert_from_probed_handler
        finish_dialog(:expert_from_probed)
      end

      def handle_event(input)
        if @actions_presenter.can_handle?(input)
          @actions_presenter.update_status(input)
          Yast::UI.ChangeWidget(Id(:summary), :Value, @actions_presenter.to_html)
        end
      end

    protected

      attr_writer :proposal
      # Desired devicegraph
      attr_writer :devicegraph

      # Calculates the desired devicegraph using the storage proposal.
      # Sets the devicegraph to nil if something went wrong
      def propose!
        return if proposal.nil? || proposal.proposed?

        proposal.propose
        self.devicegraph = proposal.devices
      rescue Y2Storage::Error
        log.error("generating proposal failed")
        self.devicegraph = nil
      end

      # HTML-formatted text to display in the dialog
      #
      # If there is a successful proposal, it returns a text representation of
      # the proposal with links to modify the settings.
      #
      # If the devicegraph has been set manually, it shows the actions to
      # perform.
      #
      # If there was an error calculating the proposal, it returns an error
      # message.
      #
      # @return [String]
      def summary
        # TODO: if there is a proposal, use the meaningful description with
        # hyperlinks instead of just delegating the summary to libstorage
        content = if devicegraph
          @actions_presenter.to_html
        else
          Yast::HTML.Para(Yast::HTML.Colorize(_("No proposal possible."), "red"))
        end

        RichText(Id(:summary), content)
      end

      def dialog_title
        _("Suggested Partitioning")
      end

      def expert_partitioner
        items = []
        if devicegraph
          items << Item(Id(:expert_from_proposal), _("Start with Current Proposal"))
        end
        items << Item(Id(:expert_from_probed), _("Start with Existing Partitions"))
        MenuButton(_("Expert Partitioner"), items)
      end

      def dialog_content
        MarginBox(
          2, 1,
          VBox(
            MinHeight(8, summary),
            PushButton(Id(:guided), _("Guided Setup")),
            expert_partitioner
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
