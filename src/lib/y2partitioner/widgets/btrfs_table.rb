require "yast"
require "cwm/table"
require "y2partitioner/widgets/blk_devices_table"
require "y2partitioner/widgets/help"
require "y2partitioner/device_graphs"

module Y2Partitioner
  module Widgets
    # Table widget to represent the Btrfs filesystems
    class BtrfsTable < CWM::Table
      include BlkDevicesTable
      include Help

      attr_reader :filesystems

      # @param filesystems [Array<Y2Storage::BlkFilesystem>] btrfs filesystems
      def initialize(filesystems)
        textdomain "storage"
        @filesystems = filesystems
      end

      def header
        columns.map { |c| send("#{c}_title") }
      end

      def items
        filesystems.map { |f| values_for(f) }
      end

      def selected_filesystem
        return nil if items.empty? || !value

        device_name = value[/table:partition:(.*)/, 1]
        device = Y2Storage::BlkDevice.find_by_name(DeviceGraphs.instance.current, device_name)
        device.filesystem
      end

      def help
        header = _(
          "<p>This view shows all Btrfs filesystems.</p>" \
          "<p>The table contains:</p>" \
        )
        fields = HELP_FIELDS.map { |f| helptext_for(f) }.join("\n")
        header + fields
      end

    private

      HELP_FIELDS = [:device, :size, :format, :encrypted, :type, :fs_type,
                     :label, :mount_point].freeze

      def columns
        [
          :device,
          :size,
          :format,
          :encryption,
          :device_type,
          :filesystem_type,
          :filesystem_label,
          :mount_point
        ]
      end

      def values_for(filesystem)
        [row_id(filesystem)] + columns.map { |c| send("#{c}_value", filesystem) }
      end

      def row_id(filesystem)
        id_for_device(device(filesystem))
      end

      # FIXME: Btrfs could belong to several devices
      def device(filesystem)
        filesystem.plain_blk_devices.first
      end

      # Column titles

      def device_title
        # TRANSLATORS: table header, Device is physical name of block device, e.g. "/dev/sda1"
        _("Device")
      end

      def size_title
        # TRANSLATORS: table header, size of block device e.g. "8.00 GiB"
        Right(_("Size"))
      end

      def format_title
        # TRANSLATORS: table header, "F" stands for Format flag. Keep it short,
        # ideally single letter
        Center(_(BlkDevicesTable::FORMAT_FLAG))
      end

      def encryption_title
        # TRANSLATORS: table header, flag if device is encrypted. Keep it short,
        # ideally three letters. Keep in sync with Enc used later for format marker.
        Center(_("Enc"))
      end

      def device_type_title
        # TRANSLATORS: table header, type of disk or partition. Can be longer. E.g. "Linux swap"
        _("Type")
      end

      def filesystem_type_title
        # TRANSLATORS: table header, Files system type. In this case "BtrFS"
        _("FS Type")
      end

      def filesystem_label_title
        # TRANSLATORS: table header, disk or partition label. Can be empty.
        _("Label")
      end

      def mount_point_title
        # TRANSLATORS: table header, where is device mounted. Can be empty. E.g. "/" or "/home"
        _("Mount Point")
      end

      # Values

      def device_value(filesystem)
        device(filesystem).name
      end

      def size_value(filesystem)
        device(filesystem).size.to_human_string
      end

      def format_value(filesystem)
        already_formatted = !device(filesystem).to_be_formatted?(DeviceGraphs.instance.system)
        already_formatted ? "" : _(BlkDevicesTable::FORMAT_FLAG)
      end

      def encryption_value(filesystem)
        encryption_value_for(device(filesystem))
      end

      def device_type_value(filesystem)
        type_for(device(filesystem))
      end

      def filesystem_type_value(filesystem)
        filesystem.type.to_human
      end

      def filesystem_label_value(filesystem)
        filesystem.label
      end

      def mount_point_value(filesystem)
        filesystem.mount_point
      end
    end
  end
end
