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
require "y2storage/dialogs/proposal"
require "y2storage/dialogs/guided_setup"
require "expert_partitioner/main_dialog"

module Y2Storage
  module Clients
    # Sets the staging devicegraph and related information during installation.
    # Delegates the calculations to the corresponding dialogs:
    #  Dialogs::Proposal to calculate the proposal
    #  Dialogs::GuidedSetup to calculate the proposal settings
    #  ToBeDefined to manually calculate a devicegraph
    class InstDiskProposal
      include Yast
      include Yast::Logger

      def initialize
        # FIXME: use StorageManager#staging when everything is adapted
        @devicegraph = storage_manager.y2storage_staging
        @proposal = storage_manager.proposal
        return if @proposal || storage_manager.staging_changed?
        # If the staging devicegraph has never been set,
        # start with a fresh proposal
        @proposal = new_proposal(new_settings)
      end

      def run
        log.info("BEGIN of inst_disk_proposal")

        until [:back, :next, :abort].include?(@result)
          dialog = Dialogs::Proposal.new(@proposal, @devicegraph)
          @result = dialog.run
          @proposal = dialog.proposal
          @devicegraph = dialog.devicegraph

          case @result
          when :next
            save_to_storage_manager
          when :guided
            settings = dialog.proposal ? dialog.proposal.settings : new_settings
            guided_setup(settings)
          when :expert
            # TODO
            expert_partitioner
          end
        end

        log.info("END of inst_disk_proposal (#{@result})")
        @result
      end

    private

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

      def guided_setup(settings)
        dialog = Dialogs::GuidedSetup.new(settings, probed_analyzer)
        case dialog.run
        when :abort
          @result = :abort
        when :next
          @proposal = new_proposal(dialog.settings)
        end
      end

      def expert_partitioner
        ExpertPartitioner::MainDialog.new.run
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

      # A new storage proposal using probed and its disk analyzer. Used to
      # ensure we share the DiskAnalyzer object (and hence we reuse its results)
      # between the proposal and the dialogs.
      def new_proposal(settings)
        probed = storage_manager.y2storage_probed
        GuidedProposal.new(settings: settings, devicegraph: probed, disk_analyzer: probed_analyzer)
      end
    end
  end
end
