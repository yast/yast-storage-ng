require "yast"
require "cwm/table"

require "y2partitioner/icons"
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/help"

module Y2Partitioner
  module Widgets
    # Table widget to represent a given list of devices
    class BlkDevicesTable < CWM::Table
      include Help
      include Yast::I18n
      extend Yast::I18n

      # Constructor
      #
      # @param devices [Array<Y2Storage::Device>]
      # @param pager [CWM::TreePager]
      def initialize(devices, pager)
        textdomain "storage"

        @devices = devices
        @pager = pager
      end

      # @see CWM::Table#header
      def header
        columns.map { |c| send("#{c}_title") }
      end

      # @see CWM::Table#items
      def items
        devices.map { |d| values_for(d) }
      end

      def opt
        [:notify]
      end

      # @macro seeAbstractWidget
      def handle
        id = value[/table:(.*)/, 1]
        @pager.handle("ID" => id)
      end

      # Updates table content
      def refresh
        change_items(items)
      end

      # Device object selected in the table
      #
      # @return [Y2Storage::Device, nil] nil if anything is selected
      def selected_device
        return nil if items.empty? || !value

        sid = value[/.*:(.*)/, 1].to_i
        devicegraph.find_device(sid)
      end

      # Adds new columns to show in the table
      #
      # @note When a column :column_name is added, the methods #column_name_title
      #   and #column_name_value should exist.
      #
      # @param column_names [*Symbol]
      def add_columns(*column_names)
        columns.concat(column_names)
      end

      # Avoids to show some columns in the table
      #
      # @param column_names [*Symbol]
      def remove_columns(*column_names)
        column_names.each { |c| columns.delete(c) }
      end

      # Fixes a set of specific columns to show in the table
      #
      # @param column_names [*Symbol]
      def show_columns(*column_names)
        @columns = column_names
      end

      # @macro seeAbstractWidget
      # @see #columns_help
      def help
        header = _(
          "<p>This view shows storage devices.</p>" \
          "<p>The overview contains:</p>" \
        )

        header + columns_help
      end

    private

      attr_reader :pager
      attr_reader :devices

      # TRANSLATORS: table header, "F" stands for Format flag. Keep it short,
      # ideally single letter.
      FORMAT_FLAG = N_("F")

      def devicegraph
        DeviceGraphs.instance.current
      end

      def columns
        @columns ||= default_columns
      end

      def default_columns
        [
          :device,
          :size,
          :format,
          :encrypted,
          :type,
          :filesystem_type,
          :filesystem_label,
          :mount_point,
          :start_cyl,
          :end_cyl
        ]
      end

      # @see #helptext_for
      def columns_help
        columns.map { |c| helptext_for(c) }.join("\n")
      end

      def values_for(device)
        [row_id(device)] + columns.map { |c| send("#{c}_value", device) }
      end

      def row_id(device)
        "table:device:#{device.sid}"
      end

      def filesystem(device)
        return nil unless device.respond_to?(:filesystem)
        device.filesystem
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

      def encrypted_title
        # TRANSLATORS: table header, flag if device is encrypted. Keep it short,
        # ideally three letters. Keep in sync with Enc used later for format marker.
        Center(_("Enc"))
      end

      def type_title
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

      def start_cyl_title
        # TRANSLATORS: table header, which sector is the first one for device. E.g. "0"
        Right(_("Start"))
      end

      def end_cyl_title
        # TRANSLATORS: table header, which sector is the the last for device. E.g. "126"
        Right(_("End"))
      end

      # Values

      def device_value(device)
        device.name
      end

      def size_value(device)
        device.size.to_human_string
      end

      def format_value(device)
        return "" unless device.respond_to?(:to_be_formatted?)
        already_formatted = !device.to_be_formatted?(DeviceGraphs.instance.system)
        already_formatted ? "" : _(BlkDevicesTable::FORMAT_FLAG)
      end

      def encrypted_value(device)
        return "" unless device.respond_to?(:encrypted?)
        return "" unless device.encrypted?

        if Yast::UI.GetDisplayInfo["HasIconSupport"]
          icon_path = Icons.small_icon(Icons::ENCRYPTED)
          cell(icon(icon_path))
        else
          "E"
        end
      end

      def type_value(_device)
        # TODO: add PartitionType#to_human_string to yast2-storage-ng.
        # TODO: also type for disks. Old one: https://github.com/yast/yast-storage/blob/master/src/modules/StorageFields.rb#L517
        #   for disk, lets add it to partitioner, unless someone else need it
        "TODO"
      end

      def filesystem_type_value(device)
        fs = filesystem(device)
        return "" if fs.nil?

        type = fs.type
        type.nil? ? "" : type.to_human
      end

      def filesystem_label_value(device)
        fs = filesystem(device)
        fs.nil? ? "" : fs.label
      end

      def mount_point_value(device)
        fs = filesystem(device)
        fs.nil? ? "" : fs.mount_point
      end

      def start_cyl_value(device)
        return "" unless device.respond_to?(:region)
        device.region.start
      end

      def end_cyl_value(device)
        return "" unless device.respond_to?(:region)
        device.region.end
      end
    end
  end
end
