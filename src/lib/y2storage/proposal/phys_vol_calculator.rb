# Copyright (c) [2015-2019] SUSE LLC
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

require "y2storage/proposal/phys_vol_strategies"

module Y2Storage
  module Proposal
    # Class used by PartitionsDistributionCalculator to find the best
    # distribution of LVM physical volumes.
    class PhysVolCalculator
      include Yast::Logger

      STRATEGIES = {
        use_needed:    PhysVolStrategies::UseNeeded,
        use_available: PhysVolStrategies::UseAvailable
      }

      # Initialize.
      #
      # @param all_spaces [Array<FreeDiskSpace>] Disk spaces that could
      #     potentially contain physical volumes
      # @param planned_vg [Planned::LvmVg] volume group to create the PVs for
      def initialize(all_spaces, planned_vg)
        @planned_vg = planned_vg
        @all_spaces = spaces_in_valid_disks(all_spaces)

        strategy = planned_vg.size_strategy
        if STRATEGIES[strategy]
          @strategy_class = STRATEGIES[strategy]
        else
          err_msg = "Unsupported LVM strategy: #{strategy}"
          log.error err_msg
          raise ArgumentError, err_msg
        end
      end

      # Extended distribution that includes a planned partition for every
      # physical volumes that would be necessary to fulfill the LVM requirements
      #
      # @note This is delegated to one of the existing strategy classes in the
      #   {PhysVolStrategies} namespace. The concrete class is decided based on
      #   the `lvm_vg_strategy` attribute of the proposal settings.
      #
      # @param distribution [Planned::PartitionsDistribution] initial
      #     distribution
      # @return [Planned::PartitionsDistribution, nil] nil if it's
      #     impossible to allocate all the needed physical volumes
      def add_physical_volumes(distribution)
        @strategy_class.new(distribution, @all_spaces, @planned_vg).add_physical_volumes
      end

      protected

      # Subset of spaces that are located in acceptable devices
      #
      # Filters the original list to only include spaces in those disks that are
      # acceptable for the planned VG. Usually that means simply returning the original
      # list back.
      #
      # @param all_spaces [Array<FreeDiskSpace>] full set of spaces
      # @return [Array<FreeDiskSpace>] subset of spaces that could contain a
      #   physical volume
      def spaces_in_valid_disks(all_spaces)
        disk_name = @planned_vg.forced_disk_name
        return all_spaces unless disk_name

        all_spaces.select { |i| i.disk_name == disk_name }
      end
    end
  end
end
