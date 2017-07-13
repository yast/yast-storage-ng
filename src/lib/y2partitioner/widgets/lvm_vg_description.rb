require "cwm/widget"
require "y2partitioner/widgets/help"

Yast.import "HTML"

module Y2Partitioner
  module Widgets
    # Widget that is richtext filled with description of LVM volume group passed in constructor
    class LvmVgDescription < CWM::RichText
      include Yast::I18n
      include Help

      # @param lvm_vg [Y2Storage::LvmVg] to describe
      def initialize(lvm_vg)
        textdomain "storage"
        @lvm_vg = lvm_vg
      end

      # inits widget content
      def init
        self.value = lvm_vg_text
      end

      HELP_FIELDS = [:device, :size, :pe_size].freeze
      # @macro seeAbstractWidget
      def help
        header = _(
          "<p>This view shows detailed information about the\nselected volume group.</p>" \
          "<p>The overview contains:</p>"
        )
        fields = HELP_FIELDS.map { |f| helptext_for(f) }.join("\n")
        header + fields
      end

    private

      def lvm_vg_text
        # TODO: consider using e.g. erb for this kind of output
        # for erb examples see
        # https://github.com/yast/yast-registration/blob/master/src/data/registration/certificate_summary.erb
        # https://github.com/yast/yast-registration/blob/327ab34c020a89f8b7e3f4bff55deea82e457237/src/lib/registration/helpers.rb#L165
        # TRANSLATORS: heading for section about device
        output = Yast::HTML.Heading(_("Device:"))
        output << Yast::HTML.List(device_attributes_list)
        # TRANSLATORS: heading for section about Hard Disk details
        output << Yast::HTML.Heading(_("LVM:"))
        output << Yast::HTML.List(lvm_vg_attributes_list)
      end

      def lvm_vg_attributes_list
        [
          # TRANSLATORS: Physical Extend size
          format(_("PE Size: %s"), @lvm_vg.extent_size.to_human_string)
        ]
      end

      def device_attributes_list
        [
          format(_("Device: %s"), "/dev/" + @lvm_vg.vg_name),
          format(_("Size: %s"), @lvm_vg.size.to_human_string)
        ]
      end
    end
  end
end
