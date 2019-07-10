# Copyright (c) [2019] SUSE LLjkkC#
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

module Y2Storage
  module Dialogs
    class GuidedSetup
      module Helpers
        # Helper that provides a handful of methods to query information related to candidate disks,
        # mainly about partitions.
        class CandidateDisks
          # Constructor
          #
          # @param settings [ProposalSettings]
          # @param analyzer [Y2Storage::DiskAnalayzer]
          def initialize(settings, analyzer)
            @settings = settings
            @analyzer = analyzer
          end

          # Candidate disks to perform the installation
          #
          # @return
          def candidate_disks
            return @candidate_disks if @candidate_disks

            candidates = settings.candidate_devices || []
            @candidate_disks = candidates.map { |d| analyzer.device_by_name(d) }
          end

          # Candidate disks names
          #
          # @return [Array<String>]
          def candidate_disks_names
            candidate_disks.map(&:name)
          end

          # Whether there is only one candidate disk
          #
          # @return [Boolean]
          def single_candidate_disk?
            candidate_disks.size == 1
          end

          # All partitions from the candidate disks
          #
          # @return [Array<Y2Storage::Partition>]
          def partitions
            @partitions ||= candidate_disks.map(&:partitions).flatten
          end

          # Whether the actions (delete or resize) over Windows partitions are configurable
          #
          # @return [Boolean]
          def windows_partitions?
            !windows_partitions.empty?
          end

          # Whether the actions (delete) over Linux partitions are configurable
          #
          # @return [Boolean]
          def linux_partitions?
            !linux_partitions.empty?
          end

          # Whether the actions (delete) over other kind of partitions are configurable
          #
          # @return [Boolean]
          def other_partitions?
            partitions.size > linux_partitions.size + windows_partitions.size
          end

          # Windows partitions from the candidate disks
          #
          # @return [Array<Y2Storage::Partition>]
          def windows_partitions
            analyzer.windows_partitions(*candidate_disks)
          end

          # Linux partitions from the candidate disks
          #
          # @return [Array<Y2Storage::Partition>]
          def linux_partitions
            analyzer.linux_partitions(*candidate_disks)
          end

          private

          attr_reader :settings, :analyzer
        end
      end
    end
  end
end
