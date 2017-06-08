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

require "y2storage/proposal/partitions_distribution_calculator"
# TODO: fix distribution calculator to don't require this
require "y2storage/proposal/lvm_helper"
require "y2storage/proposal/partition_creator"

module Y2Storage
  module Proposal
    # Class to create and reuse devices during the AutoYaST proposal, based
    # on the information contained in the profile.
    class AutoinstDevicesCreator
      include Yast::Logger

      def initialize(original_graph)
        @original_graph = original_graph
      end

      def devicegraph(planned_devices, disk_names)
        planned_partitions = planned_devices.select { |dev| dev.is_a?(Planned::Partition) }
        reused, created = planned_partitions.partition(&:reuse?)

        log.info "Partitions to reuse (#{reused.map(&:reuse)}): #{reused}"
        log.info "Partitions to create: #{created}"

        dist = best_distribution(created, disk_names)
        part_creator = Proposal::PartitionCreator.new(original_graph)
        result = part_creator.create_partitions(dist)

        reused.each do |planned|
          planned.reuse!(result)
        end
        result
      end

    protected

      attr_reader :original_graph

      def best_distribution(planned_partitions, disk_names)
        disks = original_graph.disks.select { |d| disk_names.include?(d.name) }
        spaces = disks.map(&:free_spaces).flatten
        # TODO: lvm_helper no obligatorio
        calculator = Proposal::PartitionsDistributionCalculator.new(Proposal::LvmHelper.new([]))

        calculator.best_distribution(planned_partitions, spaces)
      end
    end
  end
end
