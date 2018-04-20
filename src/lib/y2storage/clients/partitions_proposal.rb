#!/usr/bin/env ruby
#
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
require "y2storage"
require "y2storage/actions_presenter"
require "installation/proposal_client"
require "y2partitioner/dialogs/main"

Yast.import "Popup"

module Y2Storage
  module Clients
    # Proposal client to show the list of storage actions.
    #
    # This client is used in autoyast summary dialog, where a new
    # client instance is created with each event that requires to
    # update the summary dialog content.
    #
    # To manage collapsing/expanding subvolumes list it is necessary
    # to save the previous state of that list, but it is not possible
    # to do that in the client instance itself because a new client
    # instance is created each time.
    #
    # To solve that, instance class attributes are used. PartitionsProposal
    # class has an internal state that is updated with each object creation.
    #
    # @see PartitionsProposal.update_state
    class PartitionsProposal < ::Installation::ProposalClient
      include Yast::Logger
      include InstDialogMixin

      def initialize
        textdomain "storage"
        @failed = false
        @simple_mode = false
        ensure_proposed unless storage_manager.staging_changed?
        self.class.update_state
      end

      def make_proposal(param)
        @simple_mode = param["simple_mode"] || false
        failed ? failed_proposal : successful_proposal
      end

      def ask_user(param)
        event = param["chosen_id"]

        # Also run the expert partitioner as default option if no id was
        # specified by the caller (bsc#1076732)
        if event == description["id"] || event.nil?
          result = expert_partitioner
          result = { next: :again, back: :back, abort: :finish }[result]
        elsif actions_presenter.can_handle?(event)
          actions_presenter.update_status(event)
          result = :again
        else
          Yast::Report.Warning(_("This is not enabled at this moment (event: %s)") % event)
          log.warn("WARNING: impossible to manage event #{event}")
          result = :back
        end

        { "workflow_sequence" => result }
      end

      def description
        {
          "id"              => "partitions",
          "rich_text_title" => _("Partitioning"),
          "menu_title"      => _("&Partitioning")
        }
      end

    private

      attr_reader :failed

      class << self
        attr_accessor :staging_revision
        attr_accessor :actions_presenter

        # Updates internal class state when it is necessary.
        #
        # A new actions presenter is created when the current staging revision
        # is different to the last saved revision.
        #
        # @see ActionsPresenter
        def update_state
          storage_manager = StorageManager.instance
          return if staging_revision == storage_manager.staging_revision

          self.staging_revision = storage_manager.staging_revision

          staging = storage_manager.staging
          actiongraph = staging ? staging.actiongraph : nil
          self.actions_presenter = ActionsPresenter.new(actiongraph)
        end
      end

      def actions_presenter
        self.class.actions_presenter
      end

      def staging_revision
        self.class.staging_revision
      end

      def storage_manager
        StorageManager.instance
      end

      def failed_proposal
        {
          "preformatted_proposal" => nil,
          "links"                 => [],
          "language_changed"      => false,
          "warning"               => _("No proposal possible with the current settings"),
          "warning_level"         => :blocker,
          "label_proposal"        => [_("No proposal possible with the current settings")]
        }
      end

      def successful_proposal
        {
          "preformatted_proposal" => actions_presenter.to_html,
          "links"                 => actions_presenter.events,
          "language_changed"      => false,
          "label_proposal"        => [simple_proposal]
        }
      end

      def simple_proposal
        # Translators: Short description of the partitioning setup
        manual_partitioning? ? _("Custom") : _("Default")
      end

      def manual_partitioning?
        storage_manager.proposal.nil?
      end

      def ensure_proposed
        if storage_manager.proposal.nil?
          storage_manager.proposal = GuidedProposal.initial
        elsif !storage_manager.proposal.proposed?
          storage_manager.proposal.propose
        end
      rescue Y2Storage::Error
        @failed = true
        log.error("generating proposal failed")
      end

      def expert_partitioner
        probed = storage_manager.probed
        staging = storage_manager.staging
        dialog = Y2Partitioner::Dialogs::Main.new(probed, staging)
        result = without_title_on_left { dialog.run }
        storage_manager.staging = dialog.device_graph if result == :next
        result
      end
    end
  end
end
