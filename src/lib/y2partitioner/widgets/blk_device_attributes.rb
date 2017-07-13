require "yast/i18n"

Yast.import "HTML"

module Y2Partitioner
  module Widgets
    # helper to share helpers to print common attributes
    # for Block Devices
    # Main goal is to share functionality for *Description widgets.
    # Requirement for this module is to have blk_device method that
    # returns Y2Storage::BlkDevice instance.
    module BlkDeviceAttributes
      extend Yast::I18n

      # sets textdomain
      def included(_target)
        textdomain "storage"
      end

      # kernel device name formatted
      # @return [String]
      def device_name
        # TRANSLATORS: here device stands for kernel path to device
        format(_("Device: %s"), blk_device.name)
      end

      # Block device size
      # @return [String] device size in human readable format
      def device_size
        # TRANSLATORS: size of partition
        format(_("Size: %s"), blk_device.size.to_human_string)
      end

      # Udev by path links for device in human readable format
      # @return [Array<String>]
      def device_udev_by_path
        paths = blk_device.udev_paths
        if paths.size > 1
          paths.each_with_index.map do |path, index|
            # TRANSLATORS: Device path is where on motherboard is device connected,
            # %i is number when there are more paths
            format(_("Device Path %i: %s"), index + 1, path)
          end
        else
          # TRANSLATORS: Device path is where on motherboard is device connected
          [format(_("Device Path: %s"), paths.first)]
        end
      end

      # Udev by id links for device in human readable format
      # @return [Array<String>]
      def device_udev_by_id
        ids = blk_device.udev_ids
        if ids.size > 1
          ids.each_with_index.map do |id, index|
            # TRANSLATORS: Device ID is udev ID for device,
            # %i is number when there are more paths
            format(_("Device ID %i: %s"), index + 1, id)
          end
        else
          # TRANSLATORS: Device ID is udev ID for device,
          [format(_("Device ID: %s"), ids.first)]
        end
      end

      # Information if device is encrypted
      # @return [String]
      def device_encrypted
        format(_("Encrypted: %s"), blk_device.encrypted? ? _("Yes") : _("No"))
      end

      # Returns richtext description of File System on block device
      def fs_text
        # TRANSLATORS: heading for section about Filesystem on device
        Yast::HTML.Heading(_("File System:")) +
          Yast::HTML.List(filesystem_attributes_list)
      end

      # list of filesystem attributes
      def filesystem_attributes_list
        fs_type = blk_device.filesystem_type
        [
          # TRANSLATORS: File system and its type as human string
          format(_("File System: %s"), fs_type ? fs_type.to_human_string : ""),
          # TRANSLATORS: File system and its type as human string
          format(_("Mount Point: %s"), blk_device.filesystem_mountpoint || ""),
          # TRANSLATORS: Label associated with file system
          format(_("Label: %s"), blk_device.filesystem_label || "")
        ]
      end
    end
  end
end
