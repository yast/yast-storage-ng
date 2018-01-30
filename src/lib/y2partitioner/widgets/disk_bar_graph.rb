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

require "cwm/widget"

module Y2Partitioner
  module Widgets
    # Widget that shows bar graph for given disk if UI support it
    class DiskBarGraph < CWM::CustomWidget
      def initialize(disk)
        textdomain "storage"
        @disk = disk
      end

      # @return [Array<Array(Y2Storage::Region,String)>]
      #   regions with labels, sorted by region start
      def regions_and_labels
        free_regions = @disk.free_spaces.map do |fs|
          [fs.region, _("Unpartitioned")]
        end

        partitions = @disk.partitions.map do |part|
          [part.region, part.basename]
        end

        (free_regions + partitions).sort_by { |i| i[0].start }
      end

      # @macro seeCustomWidget
      def contents
        return Empty() unless Yast::UI.HasSpecialWidget(:BarGraph)
        data = regions_and_labels
        # lets use size in MiB, disks are now so big, that otherwise it will overflow
        # even for few TB and we passing values to libyui in too low data. Ignoring anything
        # below 1MiB looks OK for me (JReidinger)
        sizes = data.map { |(region, _)| region.size.to_i / (2**20) }
        labels = data.map do |(region, label)|
          label + "\n" + region.size.to_human_string
        end
        BarGraph(sizes, labels)
      end
    end
  end
end
