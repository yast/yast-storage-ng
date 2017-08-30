require "yast"
require "y2partitioner/widgets/blk_devices_table"

module Y2Partitioner
  module Widgets
    # Table widget to represent a given list of Y2Storage::Mds together.
    class MdRaidsTable < BlkDevicesTable
      # Constructor
      #
      # @param devices [Array<Y2Storage::Md>] devices to display
      # @param pager [CWM::Pager] table have feature, that double click change content of pager
      #   if someone do not need this feature, make it only optional
      def initialize(devices, pager)
        super
        add_columns(:raid_type, :chunk_size)
        remove_columns(:start, :end)
      end

    private

      def raid_type_title
        # TRANSLATORS: table header, type of md raid.
        _("RAID Type")
      end

      def chunk_size_title
        # TRANSLATORS: table header, chunk size of md raid
        _("Chunk Size")
      end

      def raid_type_value(device)
        device.md_level.to_human_string
      end

      def chunk_size_value(device)
        # according to mdadm(8): chunk size "is only meaningful for RAID0, RAID4,
        # RAID5, RAID6, and RAID10"
        device.chunk_size.zero? ? "" : device.chunk_size.to_human_string
      end
    end
  end
end
