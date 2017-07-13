require "yast"

require "cwm/table"

require "y2partitioner/icons"

module Y2Partitioner
  module Widgets
    # Module for tables that have block devices. Provides set of helpers.
    # Requires to have method pager which returns CWM::Pager
    module BlkDevicesTable
      include Yast::I18n
      extend Yast::I18n

      def included(_obj)
        textdomain "storage"
      end

      # @macro seeAbstractWidget
      def opt
        [:notify]
      end

      # @macro seeAbstractWidget
      def handle
        id = value[/table:(.*)/, 1]
        @pager.handle("ID" => id)
      end

      # TRANSLATORS: table header, "F" stands for Format flag. Keep it short,
      # ideally single letter.
      FORMAT_FLAG = N_("F")

    protected

      def encryption_value_for(device)
        return "" unless device.respond_to?(:encrypted?)
        return "" unless device.encrypted?

        if Yast::UI.GetDisplayInfo["HasIconSupport"]
          icon_path = Icons.small_icon(Icons::ENCRYPTED)
          cell(icon(icon_path))
        else
          "E"
        end
      end

      TYPE_ID_MAPPING = {
        partition:  ->(device) { "partition:#{device.name}" },
        disk:       ->(device) { "disk:#{device.name}" },
        encryption: ->(device) { "encryption:#{device.name}" },
        lvm_lv:     ->(device) { "lvm_lv:#{device.lv_name}" },
        lvm_vg:     ->(device) { "lvm_lv:#{device.vg_name}" },
        md:         ->(device) { "md:#{device.name}" }
      }.freeze
      # helper to generate id that can be later used in handle
      # @note keep in sync with ids used in overview widget
      def id_for_device(device)
        _, suffix_call = TYPE_ID_MAPPING.find do |type, _call|
          device.is?(type)
        end

        raise "unsuported type #{device.inspect}" unless suffix_call

        "table:" + suffix_call.call(device)
      end

      def type_for(_device)
        # TODO: add PartitionType#to_human_string to yast2-storage-ng.
        # TODO: also type for disks. Old one: https://github.com/yast/yast-storage/blob/master/src/modules/StorageFields.rb#L517
        #   for disk, lets add it to partitioner, unless someone else need it
        "TODO"
      end

      def fs_type_for(device)
        return "" unless device.respond_to?(:filesystem) # device which cannot have fs

        fs_type = device.filesystem_type

        fs_type ? fs_type.to_human : ""
      end
    end
  end
end
