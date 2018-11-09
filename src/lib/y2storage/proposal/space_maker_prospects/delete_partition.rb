#!/usr/bin/env ruby
#
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

require "y2storage/proposal/space_maker_prospects/partition_prospect"

module Y2Storage
  module Proposal
    module SpaceMakerProspects
      # Represents the prospect action of deleting a given partition
      #
      # @see Base
      class DeletePartition < PartitionProspect
        # Type of the partition to be deleted, according to DiskAnalyzer
        #
        # @return [Symbol] :windows, :linux or :other
        def partition_type
          @partition_type ||=
            if analyzer.windows_partitions(disk_name).any? { |part| part.name == device_name }
              :windows
            elsif analyzer.linux_partitions(disk_name).any? { |part| part.name == device_name }
              :linux
            else
              :other
            end
        end

        # Whether performing the action would be acceptable
        #
        # @param settings [ProposalSettings]
        # @param keep [Array<Integer>] list of sids of partitions that should be kept
        # @return [Boolean]
        def allowed?(settings, keep)
          return false if keep.include?(sid)
          !settings.delete_forbidden?(partition_type)
        end

        # @return [String]
        def to_s
          "<#{sid} (#{device_name}) - #{partition_type}>"
        end

        # @return [Symbol]
        def to_sym
          :delete_partition
        end
      end
    end
  end
end
