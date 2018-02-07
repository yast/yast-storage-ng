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

require "y2storage/planned"
require "y2storage/proposal/creator_result"

module Y2Storage
  module Proposal
    # Class to create an MD array according to a Planned::Md object
    class MdCreator
      include Yast::Logger

      # @return [Devicegraph] initial devicegraph
      attr_reader :original_devicegraph

      # Constructor
      #
      # @param original_devicegraph [Devicegraph] Initial devicegraph
      def initialize(original_devicegraph)
        @original_devicegraph = original_devicegraph
      end

      # Creates the MD RAID device
      #
      # @param planned_md   [Planned::Md]     MD RAID to create
      # @param device_names [Array<String>]   names of block devices that should
      #   be part of the array
      # @return [CreatorResult] Result containing the new MD array
      def create_md(planned_md, device_names)
        new_graph = original_devicegraph.duplicate
        md = Y2Storage::Md.create(new_graph, planned_md.name)

        md.md_level = planned_md.md_level if planned_md.md_level
        md.chunk_size = planned_md.chunk_size if planned_md.chunk_size
        md.md_parity = planned_md.md_parity if planned_md.md_parity

        devices = device_names.map do |dev_name|
          device = Y2Storage::BlkDevice.find_by_name(new_graph, dev_name)
          device.encryption || device
        end
        devices.map(&:remove_descendants)
        planned_md.add_devices(md, devices)

        planned_md.format!(md)

        CreatorResult.new(new_graph, md.name => planned_md)
      end
    end
  end
end
