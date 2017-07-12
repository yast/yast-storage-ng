require "cwm/widget"

Yast.import "HTML"

require "y2partitioner/widgets/blk_device_attributes"
require "y2partitioner/widgets/help"

module Y2Partitioner
  # CWM widgets for partitioner
  module Widgets
    # Widget that is richtext filled with description of partition passed in constructor
    class PartitionDescription < CWM::RichText
      include Yast::I18n
      include Help

      # @param partition [Y2Storage::Partition] to describe
      def initialize(partition)
        textdomain "storage"
        @partition = partition
      end

      # inits widget content
      def init
        self.value = partition_text
      end

      HELP_FIELDS = [:device, :size, :encrypted, :udev_path, :udev_id, :fs_id, :fs_type,
                     :mount_point, :label].freeze
      # @macro seeAbstractWidget
      def help
        header = _(
          "<p>This view shows detailed information about the\nselected partition.</p>" \
          "<p>The overview contains:</p>" \
        )
        fields = HELP_FIELDS.map { |f| helptext_for(f) }.join("\n")
        header + fields
      end

    private

      attr_reader :partition
      alias_method :blk_device, :partition

      include BlkDeviceAttributes

      def partition_text
        # TODO: consider using e.g. erb for this kind of output
        # TRANSLATORS: heading for section about device
        output = Yast::HTML.Heading(_("Device:"))
        output << Yast::HTML.List(device_attributes_list)
        # TRANSLATORS: heading for section about Filesystem on device
        output << fs_text
      end

      def device_attributes_list
        [
          device_name,
          device_size,
          device_encrypted,
          device_udev_by_path.join(Yast::HTML.Newline),
          device_udev_by_id.join(Yast::HTML.Newline),
          # TRANSLATORS: acronym for Filesystem Identifier
          format(_("FS ID: %s"), "TODO")
        ]
      end
    end
  end
end
