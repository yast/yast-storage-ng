require "cwm/widget"

# FIXME: just for Region#size
require "y2partitioner/dialogs/partition_size"

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
