# Copyright (c) [2018] SUSE LLC
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
require "y2storage/proposal/settings_generator/base"

module Y2Storage
  module Proposal
    module SettingsGenerator
      # Class for generating the settings to use in each attempt of the {InitialGuidedProposal}
      #
      # This class is meant to be used when the settings has ng format.
      #
      # @see SettingsGenerator::Base
      class Ng < Base
        private

        # Next settings to use for a new attempt of the {InitialGuidedProposal}
        #
        # It tries to disable any property from the first configurable volume: adjust by ram,
        # snapshots or the volume itself.
        #
        # @see SettingsGenerator::Base#next_settings
        #
        # @return [ProposalSettings, nil] nil if nothing else can be disabled in the current settings
        def calculate_next_settings
          volume = first_configurable_volume

          return nil if volume.nil?

          settings_after_disabling_adjust_by_ram(volume) ||
            settings_after_disabling_snapshots(volume) ||
            settings_after_disabling_volume(volume)
        end

        # Returns the first volume (according to disable_order) whose settings could be modified.
        #
        # @note Volumes without disable order are never altered.
        #
        # @return [VolumeSpecification, nil]
        def first_configurable_volume
          settings.volumes.select { |v| configurable_volume?(v) }.min_by(&:disable_order)
        end

        # Copy of the current settings after disabling adjust by ram property from the
        # given volume specification.
        #
        # @param volume [VolumeSpecification]
        # @return [ProposalSettings, nil] nil if adjust by ram is already disabled
        def settings_after_disabling_adjust_by_ram(volume)
          return nil unless adjust_by_ram_active_and_configurable?(volume)

          disable_volume_property(volume, :adjust_by_ram)

          copy_settings
        end

        # Copy of the current settings after disabling snapshots property from the
        # given volume specification.
        #
        # @param volume [VolumeSpecification]
        # @return [ProposalSettings, nil] nil if snapshots is already disabled
        def settings_after_disabling_snapshots(volume)
          return nil unless snapshots_active_and_configurable?(volume)

          disable_volume_property(volume, :snapshots)

          copy_settings
        end

        # Copy of the current settings after disabling the given volume specification
        #
        # @param volume [VolumeSpecification]
        # @return [ProposalSettings, nil] nil if the volume is already disabled
        def settings_after_disabling_volume(volume)
          return nil unless proposed_active_and_configurable?(volume)

          disable_volume_property(volume, :proposed)

          copy_settings
        end

        def disable_volume_property(volume, property)
          log.info("Disabling '#{property}' for '#{volume.mount_point}'")

          volume.public_send(:"#{property}=", false)
          @adjustments = adjustments.add_volume_attr(volume, property, false)
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
        #
        # @param volume [VolumeSpecification]
        # @return [Boolean]
        def adjust_by_ram_active_and_configurable?(volume)
          active_and_configurable?(volume, :adjust_by_ram)
        end

        # Whether the volume has snapshots to true and it could be configured
        #
        # @param volume [VolumeSpecification]
        # @return [Boolean]
        def snapshots_active_and_configurable?(volume)
          return false unless volume.fs_type.is?(:btrfs)

          active_and_configurable?(volume, :snapshots)
        end

        # Whether a volume has an attribute to true and it could be configured
        #
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
