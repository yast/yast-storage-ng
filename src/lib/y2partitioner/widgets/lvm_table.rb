require "yast"

require "cwm/table"

require "y2partitioner/icons"
require "y2partitioner/widgets/blk_devices_table"
require "y2partitioner/widgets/lvm_lv_attributes"
require "y2partitioner/widgets/help"

module Y2Partitioner
  module Widgets
    # Table widget to represent given list of Y2Storage::LvmVgs and Y2Storage::LvmLvs together.
    # For displaying Y2Storage::LvmLvs only use specialized class (see LvmLvTable)
    class LvmTable < CWM::Table
      include BlkDevicesTable
      include LvmLvAttributes
      include Help

      # @param lvms [Array<Y2Storage::LvmVg|Y2Storage::LvmLv] devices to display
      # @param pager [CWM::Pager] table have feature, that double click change content of pager
      #   if someone do not need this feature, make it only optional
      def initialize(lvms, pager)
        textdomain "storage"
        @lvms = lvms
        @pager = pager
      end

      # table items. See CWM::Table#items
      def items
        @lvms.map do |device|
          graph = DeviceGraphs.instance.system
          formatted = device.is?(:lvm_lv) && device.to_be_formatted?(graph)
          res = [
            id_for_device(device), # use name as id
            lvm_name(device),
            device.size.to_human_string,
            # TODO: dasd format use "X", check it
            formatted ? _(BlkDevicesTable::FORMAT_FLAG) : "",
            encryption_value_for(device),
            type_for(device),
            fs_type_for(device)
          ]
          res + device_specific_items(device)
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
          # TRANSLATORS: table header, type of metadata
          _("PE Size"),
          # TRANSLATORS: table header, number of LVM LV stripes
          _("Stripes")
        ]
      end

      HELP_FIELDS = [:device, :size, :format, :encrypted, :type, :fs_type,
                     :label, :mount_point, :pe_size, :stripes].freeze
      # @macro seeAbstractWidget
      def help
        header = _(
          "<p>This view shows all LVM volume groups and\ntheir logical volumes.</p>" \
          "<p>The overview contains:</p>" \
        )
        fields = HELP_FIELDS.map { |f| helptext_for(f) }.join("\n")
        header + fields
      end

    private

      attr_reader :pager

      def lvm_name(device)
        # TODO: discuss this with ancor where it make sense to have it in y2-storage
        device.is_a?(Y2Storage::LvmVg) ? "/dev/#{device.vg_name}" : device.name
      end

      def device_specific_items(device)
        case device
        when Y2Storage::LvmVg
          [
            "",
            "",
            device.extent_size.to_human_string,
            ""
          ]
        when Y2Storage::LvmLv
          [
            device.filesystem_label || "",
            device.filesystem_mountpoint || "",
            "",
            stripes_info(device)
          ]
        else
          raise "Invalid device #{device.inspect}"
        end
      end
    end
  end
end
