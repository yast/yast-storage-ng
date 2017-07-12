require "cwm/widget"

Yast.import "HTML"

require "y2partitioner/widgets/blk_device_attributes"
require "y2partitioner/widgets/lvm_lv_attributes"
require "y2partitioner/widgets/help"

module Y2Partitioner
  # CWM widgets for partitioner
  module Widgets
    # Widget that is richtext filled with description of logical volume passed in constructor
    class LvmLvDescription < CWM::RichText
      include Yast::I18n
      include Help

      # @param lvm_lv [Y2Storage::LvmLv] to describe
      def initialize(lvm_lv)
        textdomain "storage"
        @lvm_lv = lvm_lv
      end

      # inits widget content
      def init
        self.value = lv_text
      end

      HELP_FIELDS = [:device, :size, :encrypted, :udev_path, :udev_id, :fs_id, :fs_type,
                     :mount_point, :label].freeze
      # @macro seeAbstractWidget
      def help
        header = _(
          "<p>This view shows detailed information about the\nselected logical volume.</p>" \
          "<p>The overview contains:</p>"
        )
        fields = HELP_FIELDS.map { |f| helptext_for(f) }.join("\n")
        header + fields
      end

    private

      attr_reader :lvm_lv
      alias_method :blk_device, :lvm_lv

      include BlkDeviceAttributes
      include LvmLvAttributes

      def lv_text
        # TODO: consider using e.g. erb for this kind of output
        # TRANSLATORS: heading for section about device
        output = Yast::HTML.Heading(_("Device:"))
        output << Yast::HTML.List(device_attributes_list)
        output << Yast::HTML.Heading(_("LVM:"))
        output << Yast::HTML.List([stripes])
        output << fs_text
      end

      def device_attributes_list
        [
          device_name,
          device_size,
          device_encrypted
        ]
      end

      def stripes
        # TRANSLATORS: value for number of LVM stripes
        format(_("Stripes: %s"), stripes_info(lvm_lv))
      end
    end
  end
end
