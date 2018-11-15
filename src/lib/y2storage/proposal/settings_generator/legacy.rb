# encoding: utf-8

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

module Y2Storage
  module Proposal
    module SettingsGenerator
      # Class for generating the settings to use in each attempt of the {InitialGuidedProposal}
      #
      # This class is meant to be used when the settings has legacy format.
      #
      # @see SettingsGenerator::Base
      class Legacy < Base
      private

        # Next settings to use for a new attempt of the {InitialGuidedProposal}
        #
        # It tries to disable a separate home, and then, the snapshots.
        #
        # @see SettingsGenerator::Base#next_settings
        #
        # @return [ProposalSettings, nil] nil if nothing else can be disabled in the current settings
        def calculate_next_settings
          settings_without_home || settings_without_snapshots
        end

        # Copy of the current settings after disabling a separte home property
        #
        # @return [ProposalSettings, nil] nil if separate home is already disabled
        def settings_without_home
          return nil unless used_separate_home?

          disable_separate_home

          copy_settings
        end

        # Copy of the current settings after disabling the snapshots property
        #
        # @return [ProposalSettings, nil] nil if snapshots is already disabled
        def settings_without_snapshots
          return nil unless used_snapshots?

          disable_snapshots

          copy_settings
        end

        # Whether the current settings are using separate home
        #
        # @return [Boolean]
        def used_separate_home?
          !!settings.use_separate_home
        end

        # Whether the current settings are using snapshots
        #
        # @return [Boolean]
        def used_snapshots?
          settings.snapshots_active?
        end

        # Disables separate home from current settings
        def disable_separate_home
          settings.use_separate_home = false
        end

        # Disables snapshots from current settings
        def disable_snapshots
          settings.use_snapshots = false
        end
      end
    end
  end
end
