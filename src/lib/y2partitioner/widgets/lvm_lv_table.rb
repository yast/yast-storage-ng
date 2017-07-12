require "yast"

require "cwm/table"

require "y2partitioner/icons"
require "y2partitioner/widgets/blk_devices_table"
require "y2partitioner/widgets/lvm_lv_attributes"
require "y2partitioner/widgets/help"

module Y2Partitioner
  module Widgets
    # Table widget to represent given list of Y2Storage::LvmLvs together.
    class LvmLvTable < CWM::Table
      include BlkDevicesTable
      include LvmLvAttributes
      include Help

      # @param lvs [Array<Y2Storage::LvmLv] devices to display
      # @param pager [CWM::Pager] table have feature, that double click change content of pager
      #   if someone do not need this feature, make it only optional
      def initialize(lvs, pager)
        textdomain "storage"
        @lvs = lvs
        @pager = pager
      end

      # table items. See CWM::Table#items
      def items
        @lvs.map do |device|
          formatted = device.to_be_formatted?(DeviceGraphs.instance.system)
          [
            id_for_device(device), # use name as id
            device.name,
            device.size.to_human_string,
            # TODO: dasd format use "X", check it
            formatted ? _(BlkDevicesTable::FORMAT_FLAG) : "",
            encryption_value_for(device),
            type_for(device),
            fs_type_for(device),
            device.filesystem_label || "",
            device.filesystem_mountpoint || "",
            stripes_info(device)
          ]
        end
      end

      # headers of table
      def header
        [
          # TRANSLATORS: table header, Device is physical name of block device
          # like partition or disk e.g. "/dev/sda1"
          _("Device"),
          # TRANSLATORS: table header, size of block device e.g. "8.00 GiB"
          Right(_("Size")),
          Center(_(BlkDevicesTable::FORMAT_FLAG)),
          # TRANSLATORS: table header, flag if device is encrypted. Keep it short,
          # ideally three letters. Keep in sync with Enc used later for format marker.
          Center(_("Enc")),
          # TRANSLATORS: table header, type of disk or partition. Can be longer. E.g. "Linux swap"
          _("Type"),
          # TRANSLATORS: table header, Files system type. Can be empty E.g. "BtrFS"
          _("FS Type"),
          # TRANSLATORS: table header, disk or partition label. Can be empty.
          _("Label"),
          # TRANSLATORS: table header, where is device mounted. Can be empty. E.g. "/" or "/home"
          _("Mount Point"),
          # TRANSLATORS: table header, number of LVM LV stripes
          _("Stripes")
        ]
      end

      HELP_FIELDS = [:device, :size, :format, :encrypted, :type, :fs_type,
                     :label, :mount_point, :stripes].freeze
      # @macro seeAbstractWidget
      def help
        header = _(
          "<p>This view shows all logical volumes of the\nselected volume group.</p>" \
          "<p>The overview contains:</p>" \
        )
        fields = HELP_FIELDS.map { |f| helptext_for(f) }.join("\n")
        header + fields
      end

    private

      attr_reader :pager
    end
  end
end
