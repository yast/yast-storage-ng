# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "y2partitioner/widgets/help"

module Y2Partitioner
  module Widgets
    # Mixin to simplify and unify the definition of table widgets used to
    # represent collections of block devices.
    #
    # The class including this module must define the following methods:
    #
    #   * #columns returning an array of symbols
    #   * #devices returning a collection of {Y2Storage::BlkDevice}
    module BlkDeviceColumns
      extend Yast::I18n
      include Help

      textdomain "storage"

      # @see CWM::Table#header
      def header
        columns.map { |c| send("#{c}_title") }
      end

      # @see CWM::Table#items
      def items
        devices.map { |d| values_for(d) }
      end

      # Updates table content
      def refresh
        change_items(items)
      end

    protected

      # TRANSLATORS: "F" stands for Format flag. Keep it short, ideally a single letter.
      FORMAT_FLAG = N_("F")

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
        Center(_(FORMAT_FLAG))
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
        # TRANSLATORS: table header, file system type
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

      def start_title
        # TRANSLATORS: table header, which sector is the first one for device. E.g. "0"
        Right(_("Start"))
      end

      def end_title
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
        already_formatted ? "" : _(FORMAT_FLAG)
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

      def start_value(device)
        return "" unless device.respond_to?(:region)
        device.region.start
      end

      def end_value(device)
        return "" unless device.respond_to?(:region)
        device.region.end
      end
    end
  end
end
