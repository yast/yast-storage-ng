require "yast"

require "cwm/table"

require "y2partitioner/icons"
require "y2partitioner/widgets/blk_devices_table"
require "y2partitioner/widgets/help"

module Y2Partitioner
  module Widgets
    # Base class for table widgets that represent list of devices that holds plain blk device.
    class UsedDevicesTable < CWM::Table
      include BlkDevicesTable
      include Help

      # @param pager [CWM::Pager] table have feature, that double click change content of pager
      #   if someone do not need this feature, make it only optional
      def initialize(pager)
        textdomain "storage"
        @pager = pager
      end

      # !method abstract_devices
      #   Abstract method that returns list of block devices to display
      abstract_method :blk_devices

      # table items. See CWM::Table#items
      def items
        blk_devices.map do |device|
          formatted = device.to_be_formatted?(DeviceGraphs.instance.system)
          [
            id_for_device(device), # use name as id
            device.name,
            device.size.to_human_string,
            # TODO: dasd format use "X", check it
            formatted ? _(BlkDevicesTable::FORMAT_FLAG) : "",
            encryption_value_for(device),
            type_for(device)
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
          _("Type")
        ]
      end

      HELP_FIELDS = [:device, :size, :format, :encrypted, :type].freeze
      # Help without specification what is exactly device holding blk_device. Should be defined in
      # Specific child.
      # @macro seeAbstractWidget
      def help
        header = _(
          "<p>This view shows all physical volumes used by\nthe selected volume group.</p>" \
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
