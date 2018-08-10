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
require "yast/i18n"
require "yast2/popup"
require "y2storage"
require "y2storage/dump_manager"
require "y2storage/dialogs/proposal"
require "y2storage/dialogs/guided_setup"
require "y2partitioner/dialogs/main"
require "y2storage/partitioning_features"

module Y2Storage
  module Clients
    # Sets the staging devicegraph and related information during installation.
    # Delegates the calculations to the corresponding dialogs:
    #  Dialogs::Proposal to calculate the proposal
    #  Dialogs::GuidedSetup to calculate the proposal settings
    #  Y2Partitioner::Dialogs::Main to manually calculate a devicegraph
    class InstDiskProposal
      include Yast
      include Yast::I18n
      include Yast::Logger
      include InstDialogMixin
      include PartitioningFeatures

      def initialize
        textdomain "storage"

        @devicegraph = storage_manager.staging
        @proposal = storage_manager.proposal
        # Save staging revision to check later if the system was reprobed
        save_staging_revision

        return if @proposal || storage_manager.staging_changed?
        # If the staging devicegraph has never been set, try to make an initial proposal
        create_initial_proposal
      end

      def run
        log.info("BEGIN of inst_disk_proposal")

        until [:back, :next, :abort].include?(@result)
          dialog = Dialogs::Proposal.new(@proposal, @devicegraph, excluded_buttons: excluded_buttons)
          @result = dialog.run
          @proposal = dialog.proposal
          @devicegraph = dialog.devicegraph

          case @result
          when :next
            save_to_storage_manager
          when :guided
            guided_setup
          when :expert_from_proposal
            expert_partitioner(@devicegraph)
          when :expert_from_probed
            expert_partitioner(storage_manager.probed)
          end
        end

        log.info("END of inst_disk_proposal (#{@result})")
        @result
      end

    private

      # @return [Integer]
      attr_reader :initial_staging_revision

      # The user has changed partition settings using the Expert Partitioner.
      # Asking if these changes can be overwritten.
      def overwrite_manual_settings?
        ret = Popup.YesNo(_(
                            "Computing this proposal will overwrite manual changes \n"\
                            "done so far. Continue with computing proposal?"
        ))
        log.info "overwrite_manual_settings? return #{ret}"
        ret
      end

      def save_to_storage_manager
        if @proposal
          log.info "Storing accepted proposal"
          storage_manager.proposal = @proposal
        else
          log.info "Storing manually configured devicegraph"
          storage_manager.staging = @devicegraph
        end
        add_storage_packages
      end

      def guided_setup
        return if manual_partitioning? && !overwrite_manual_settings?

        settings = @proposal ? @proposal.settings : new_settings
        dialog = Dialogs::GuidedSetup.new(settings, probed_analyzer)
        case dialog.run
        when :abort
          @result = :abort
        when :next
          @proposal = new_proposal(dialog.settings)
        end
      end

      def expert_partitioner(initial_graph)
        return unless initial_graph && run_partitioner?

        dialog = Y2Partitioner::Dialogs::Main.new(storage_manager.probed, initial_graph)
        dialog_result = without_title_on_left { dialog.run }

        actions_after_partitioner(dialog.device_graph, dialog_result)
      end

      # Actions to perform after running the Partitioner
      #
      # @param devicegraph [Devicegraph] devicegraph with all changes
      # @param dialog_result [Symbol] result of the Partitioner dialog
      def actions_after_partitioner(devicegraph, dialog_result)
        case dialog_result
        when :abort
          @result = :abort
        when :next
          @proposal = nil
          @devicegraph = devicegraph
          DumpManager.dump(devicegraph, "partitioner")
        when :back
          # Try to create a proposal when the system was reprobed (bsc#1088960)
          create_initial_proposal if reprobed?
        end
      end

      # Add storage-related software packages (filesystem tools etc.) to the
      # set of packages to be installed.
      def add_storage_packages
        pkg_handler = Y2Storage::PackageHandler.new
        pkg_handler.add_feature_packages(storage_manager.staging)
        pkg_handler.set_proposal_packages
      end

      def new_settings
        res = ProposalSettings.new_for_current_product
        log.info "Read storage proposal settings from the product: #{res.inspect}"
        res
      end

      def storage_manager
        StorageManager.instance
      end

      def probed_analyzer
        storage_manager.probed_disk_analyzer
      end

      # Checks whether the system was reprobed
      #
      # @return [Boolean]
      def reprobed?
        !storage_manager.staging_changed? &&
          initial_staging_revision != storage_manager.staging_revision
      end

      # When it is not possible a proposal using current settings, some attempts
      # could be done by changing the settings
      #
      # @see GuidedProposal.initial
      def create_initial_proposal
        @proposal = GuidedProposal.initial(settings: new_settings)
        @devicegraph = @proposal.devices
        # The new proposal could be created because the system was reprobed.
        # The initial staging revision needs to be updated to avoid to create
        # a new proposal if the system was not reprobed again.
        save_staging_revision
      end

      # Saves the current staging revision as initial revision
      #
      # This value is useful to detect if the system was reprobed
      def save_staging_revision
        @initial_staging_revision = storage_manager.staging_revision
      end

      # A new storage proposal using probed and its disk analyzer. Used to
      # ensure we share the DiskAnalyzer object (and hence we reuse its results)
      # between the proposal and the dialogs.
      def new_proposal(settings)
        probed = storage_manager.probed
        GuidedProposal.new(settings: settings, devicegraph: probed, disk_analyzer: probed_analyzer)
      end

      # Buttons to be excluded in the proposal dialog
      #
      # @return [Array<Symbol>]
      def excluded_buttons
        excluded = []
        excluded << :guided unless show_guided_setup?
        excluded
      end

      # Whether it is possible to show the Guided Setup
      #
      # @see Dialogs::GuidedSetup.can_be_shown?
      #
      # @return [Boolean]
      def show_guided_setup?
        Dialogs::GuidedSetup.can_be_shown?(probed_analyzer)
      end

      # Whether to run the Partitioner
      #
      # @note Before running the partitioner a warning could be shown. In that case,
      #   the Partitioner only should be run if the user accepts the warning.
      #
      # @return [Boolean]
      def run_partitioner?
        !partitioner_warning? || partitioner_warning == :continue
      end

      # Whether the Partitioner warning should be shown
      #
      # @note This option is configured in the control file,
      #   see {Y2Storage::PartitioningFeatures#feature}. In case this setting is not
      #   indicated in the control file, default value is set to false.
      #
      # @return [Boolean]
      def partitioner_warning?
        show_warning = feature(:expert_partitioner_warning)
        show_warning.nil? ? false : show_warning
      end

      # Popup to alert the user about using the Partitioner
      #
      # @return [Symbol] user's answer (:continue, :cancel)
      def partitioner_warning
        message = _(
          "This is for experts only.\n" \
          "You might lose support if you use this!\n\n" \
          "Please refer to the manual to make sure your custom\n" \
          "partitioning meets the requirements of this product."
        )

        Yast2::Popup.show(message, headline: :warning, buttons: :continue_cancel, focus: :cancel)
      end

      # Whether the current devicegraph was configured using the Expert Partitioner
      #
      # @return [Boolean] false if staging was calculated using a proposal
      def manual_partitioning?
        @proposal.nil?
      end
    end
  end
end
