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
        # If the staging devicegraph has never been set,
        # start with a fresh proposal
        if @proposal.nil? && !storage_manager.staging_changed?
          @proposal = Proposal.new(settings: new_settings)
        end
      end

      def run
        log.info("BEGIN of inst_disk_proposal")

        until [:back, :next, :abort].include?(@result)
          guided_setup = Dialogs::GuidedSetup.new(ProposalSettings.new)
          Dialogs::GuidedSetup::SelectScheme.new(guided_setup.settings.dup).run
          return

          dialog = Dialogs::Proposal.new(@proposal, @devicegraph)
          @result = dialog.run
          @proposal = dialog.proposal
          @devicegraph = dialog.devicegraph

          p @result

          case @result
          when :next
            save_to_storage_manager
          when :guided
            settings = dialog.proposal ? dialog.proposal.settings : new_settings
            guided_setup(settings)
          when :expert
            # FIXME
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
        dialog = Dialogs::GuidedSetup.new(settings)
        res = dialog.run
        p "guided: #{res}"
        case res
        when :abort
          @result = :abort
        when :next
          @proposal = Proposal.new(settings: dialog.settings)
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
    end
  end
end
