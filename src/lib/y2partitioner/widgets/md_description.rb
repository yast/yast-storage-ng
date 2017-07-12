require "cwm/widget"

Yast.import "HTML"

require "y2partitioner/widgets/blk_device_attributes"
require "y2partitioner/widgets/help"

module Y2Partitioner
  module Widgets
    # Widget that is richtext filled with description of md raid passed in constructor
    class MdDescription < CWM::RichText
      include Yast::I18n
      include Help

      # @param md [Y2Storage::Md] to describe
      def initialize(md)
        textdomain "storage"
        @md = md
      end

      # inits widget content
      def init
        self.value = md_text
      end

      HELP_FIELDS = [:device, :size, :udev_path, :udev_id, :raid_type, :chunk_size,
                     :parity_algorithm, :fs_type, :mount_point, :label].freeze
      # @macro seeAbstractWidget
      def help
        header = _(
          "<p>This view shows detailed information about the\nselected RAID.</p>" \
          "<p>The overview contains:</p>" \
        )
        fields = HELP_FIELDS.map { |f| helptext_for(f) }.join("\n")
        header + fields
      end

    private

      attr_reader :md
      alias_method :blk_device, :md

      include BlkDeviceAttributes

      def md_text
        # TODO: consider using e.g. erb for this kind of output
        # for erb examples see
        # https://github.com/yast/yast-registration/blob/master/src/data/registration/certificate_summary.erb
        # https://github.com/yast/yast-registration/blob/327ab34c020a89f8b7e3f4bff55deea82e457237/src/lib/registration/helpers.rb#L165
        # TRANSLATORS: heading for section about device
        output = Yast::HTML.Heading(_("Device:"))
        output << Yast::HTML.List(device_attributes_list)
        # TRANSLATORS: heading for section about Hard Disk details
        output << Yast::HTML.Heading(_("RAID:"))
        output << Yast::HTML.List(raid_attributes_list)
        output << fs_text
      end

      def raid_attributes_list
        [
          # TRANSLATORS: Type of RAID
          format(_("RAID Type: %s"), md.md_level.to_human_string),
          # TRANSLATORS: chunk size of md raid
          # according to mdadm(8): chunk size "is only meaningful for RAID0, RAID4,
          # RAID5, RAID6, and RAID10"
          format(_("Chunk Size: %s"),
            md.chunk_size.zero? ? "" : md.chunk_size.to_human_string),
          # TRANSLATORS: parity algorithm of md raid
          format(_("Partity algorithm: %s"), md.md_parity.to_human_string)
        ]
      end

      def device_attributes_list
        [
          device_name,
          device_size,
          device_encrypted,
          device_udev_by_path.join(Yast::HTML.Newline),
          device_udev_by_id.join(Yast::HTML.Newline)
        ]
      end
    end
  end
end
