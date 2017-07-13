require "cwm/widget"

Yast.import "HTML"

require "y2partitioner/widgets/blk_device_attributes"
require "y2partitioner/widgets/help"

module Y2Partitioner
  module Widgets
    # Widget that is richtext filled with description of partition passed in constructor
    class DiskDescription < CWM::RichText
      include Yast::I18n
      include Help

      # @param disk [Y2Storage::Disk] to describe
      def initialize(disk)
        textdomain "storage"
        @disk = disk
      end

      # inits widget content
      def init
        self.value = disk_text
      end

      HELP_FIELDS = [:device, :size, :udev_path, :udev_id, :vendor, :model, :bus,
                     :disk_label].freeze
      # @macro seeAbstractWidget
      def help
        header = _(
          "<p>This view shows detailed information about the\nselected hard disk.</p>" \
          "<p>The overview contains:</p>" \
        )
        fields = HELP_FIELDS.map { |f| helptext_for(f) }.join("\n")
        header + fields
      end

    private

      attr_reader :disk
      alias_method :blk_device, :disk

      include BlkDeviceAttributes

      def disk_text
        # TODO: consider using e.g. erb for this kind of output
        # for erb examples see
        # https://github.com/yast/yast-registration/blob/master/src/data/registration/certificate_summary.erb
        # https://github.com/yast/yast-registration/blob/327ab34c020a89f8b7e3f4bff55deea82e457237/src/lib/registration/helpers.rb#L165
        # TRANSLATORS: heading for section about device
        output = Yast::HTML.Heading(_("Device:"))
        output << Yast::HTML.List(device_attributes_list)
        # TRANSLATORS: heading for section about Hard Disk details
        output << Yast::HTML.Heading(_("Hard Disk:"))
        output << Yast::HTML.List(disk_attributes_list)
      end

      def disk_attributes_list
        partition_table = disk.partition_table
        [
          # TRANSLATORS: Disk Vendor
          format(_("Vendor: %s"), "TODO"),
          # TRANSLATORS: Disk Model
          format(_("Model: %s"), "TODO"),
          # TODO: to_human_string for Y2Storage::DataTransport
          # TRANSLATORS: Computer bus which the device is connected to e.g. SATA or ATA.
          format(_("Bus: %s"), "TODO"),
          # TRANSLATORS: disk partition table label
          format(_("Disk Label: %s"), partition_table ? partition_table.type.to_human_string : "")
        ]
      end

      def device_attributes_list
        [
          device_name,
          device_size,
          device_udev_by_path.join(Yast::HTML.Newline),
          device_udev_by_id.join(Yast::HTML.Newline)
        ]
      end
    end
  end
end
