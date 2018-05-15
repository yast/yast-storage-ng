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
require "y2storage/proposal/initial_strategies/base"
require "y2storage/proposal/settings_adjustment"

module Y2Storage
  module Proposal
    module InitialStrategies
      # Class to calculate an initial proposal to install the system when the
      # proposal settings has ng format
      class Ng < Base
        # Calculates the initial proposal
        #
        # If a proposal is not possible by honoring current settings, other settings
        # are tried. Settings are modified in each volume according to the disable order.
        #
        # In the first iteration, it will look for the lowest number in disable_order. If
        # adjust_by_swap is optional in that volume and enabled, it will disable it. If that
        # is not enough and snapshots are optional but enabled, it will disable them and try
        # again (assuming Btrfs is being used). If that's still not enough, it will disable
        # the whole volume if it's optional.
        #
        # If that is not enough, it will keep those settings and look for the next volume to
        # perform the same operation in a cumulative fashion.
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
          proposal = try_proposal(Yast.deep_copy(current_settings), devicegraph, disk_analyzer, nil)

          loop do
            volume = first_configurable_volume(proposal.settings)

            return proposal if !proposal.failed? || volume.nil?

            proposal = try_without_adjust_by_ram(proposal, volume, devicegraph, disk_analyzer)

            proposal = try_without_snapshots(proposal, volume, devicegraph, disk_analyzer)

            proposal = try_without_proposed(proposal, volume, devicegraph, disk_analyzer)
          end
        end

      private

        # @see Base#try_proposal
        #
        # In addition to the base behavior, this adds an extra argument to keep
        # track of the adjustments done to the settings on every attempt.
        #
        # @param settings [ProposalSettings] see {Base#try_proposal}
        # @param devicegraph [Devicegraph] see {Base#try_proposal}
        # @param disk_analyzer [DiskAnalyzer] see {Base#try_proposal}
        # @param adjustment [SettingsAdjustment, nil] adjustment performed so
        #   far to the initial settings, nil for the initial attempt
        #
        # @return [GuidedProposal]
        def try_proposal(settings, devicegraph, disk_analyzer, adjustment)
          proposal = super(settings, devicegraph, disk_analyzer)
          proposal.auto_settings_adjustment = adjustment || SettingsAdjustment.new
          proposal
        end

        # Try proposal again after disabling 'adjust_by_ram'
        def try_without_adjust_by_ram(proposal, volume, devicegraph, disk_analyzer)
          if proposal.failed? && adjust_by_ram_active_and_configurable?(volume)
            proposal = retry_proposal(proposal, volume, :adjust_by_ram, devicegraph, disk_analyzer)
          end
          proposal
        end

        # Try proposal again after disabling 'snapshots'
        def try_without_snapshots(proposal, volume, devicegraph, disk_analyzer)
          if proposal.failed? && snapshots_active_and_configurable?(volume)
            proposal = retry_proposal(proposal, volume, :snapshots, devicegraph, disk_analyzer)
          end
          proposal
        end

        # Try proposal again after disabling the volume
        def try_without_proposed(proposal, volume, devicegraph, disk_analyzer)
          if proposal.failed? && proposed_active_and_configurable?(volume)
            proposal = retry_proposal(proposal, volume, :proposed, devicegraph, disk_analyzer)
          end
          proposal
        end

        # Tries a new proposal based on the previous one after having adapted
        # one of the volumes of the settings
        #
        # @note This reuses and modifies the settings from the previous
        #   proposal, that should be fine since the new proposal is aimed to
        #   replace the previous one.
        #
        # @param proposal [GuidedProposal] initial proposal, its settings will
        #   be adapted and reused (i.e. they will be modified)
        # @param volume [VolumeSpecification] it must be one of the volumes from
        #   the settings of the initial proposal
        # @param attr [Symbol] name of the attribute to disable in the volume
        # @param devicegraph [Devicegraph] see {#try_proposal}
        # @param disk_analyzer [DiskAnalyzer] see {#try_proposal}
        def retry_proposal(proposal, volume, attr, devicegraph, disk_analyzer)
          volume.send(:"#{attr}=", false)
          adjustment = proposal.auto_settings_adjustment.add_volume_attr(volume, attr, false)
          log.info("Trying proposal after disabling '#{attr}' for '#{volume.mount_point}'")
          try_proposal(proposal.settings, devicegraph, disk_analyzer, adjustment)
        end

        # Returns the first volume (according to disable_order) whose settings could be modified.
        #
        # @note Volumes without disable order are never altered.
        #
        # @param settings [ProposalSettings]
        # @return [VolumeSpecification, nil]
        def first_configurable_volume(settings)
          settings.volumes.select { |v| configurable_volume?(v) }.sort_by(&:disable_order).first
        end

        # A volume is configurable if it is proposed and its settings can be modified.
        # That is, #adjust_by_ram, #snapshots or #proposed are true and some of them
        # could be change to false.
        #
        # @note A volume is considered configurable if it has disable order. Otherwise,
        #   only the user is allowed to manually disable the volume or any of its features
        #   (e.g. snapshots) using the UI.
        #
        # @param volume [VolumeSpecification]
        # @return [Boolean]
        def configurable_volume?(volume)
          volume.proposed? && !volume.disable_order.nil? && (
            proposed_active_and_configurable?(volume) ||
            adjust_by_ram_active_and_configurable?(volume) ||
            snapshots_active_and_configurable?(volume))
        end

        # Whether the volume is proposed and it could be configured
        #
        # @param volume [VolumeSpecification]
        # @return [Boolean]
        def proposed_active_and_configurable?(volume)
          active_and_configurable?(volume, :proposed)
        end

        # Whether the volume has adjust_by_ram to true and it could be configured
        # @param volume [VolumeSpecification]
        # @return [Boolean]
        def adjust_by_ram_active_and_configurable?(volume)
          active_and_configurable?(volume, :adjust_by_ram)
        end

        # Whether the volume has snapshots to true and it could be configured
        # @param volume [VolumeSpecification]
        # @return [Boolean]
        def snapshots_active_and_configurable?(volume)
          return false unless volume.fs_type.is?(:btrfs)
          active_and_configurable?(volume, :snapshots)
        end

        # Whether a volume has an attribute to true and it could be configured
        # @param volume [VolumeSpecification]
        # @param attr [String, Symbol]
        #
        # @return [Boolean]
        def active_and_configurable?(volume, attr)
          volume.send(attr) && volume.send("#{attr}_configurable")
        end
      end
    end
  end
end
