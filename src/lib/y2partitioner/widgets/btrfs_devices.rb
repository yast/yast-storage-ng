# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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
require "yast2/popup"
require "cwm"
require "y2partitioner/widgets/btrfs_metadata_raid_level"
require "y2partitioner/widgets/btrfs_data_raid_level"
require "y2partitioner/widgets/btrfs_devices_selector"

module Y2Partitioner
  module Widgets
    # Widget grouping a set of widgets related to the selection of Btrfs devices
    #
    # It contains widgets to select the metadata/data RAID levels and also to select the devices
    # used by the filesystem.
    class BtrfsDevices < CWM::CustomWidget
      # Constructor
      #
      # @param controller [Actions::Controllers::BtrfsDevices]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
      end

      # @macro seeCustomWidget
      def contents
        VBox(
          Left(
            HVSquash(
              HBox(
                metadata_raid_level_widget,
                HSpacing(1),
                data_raid_level_widget
              )
            )
          ),
          VSpacing(1),
          btrfs_devices_selector_widget
        )
      end

      # @macro seeCustomWidget
      def help
        help_for_raid_levels + help_for_default_raid_level
      end

      # @macro seeAbstractWidget
      #
      # Validates the selected values
      #
      # An error popup is shown when there are errors in the selected values.
      #
      # @return [Boolean]
      def validate
        current_errors = errors
        return true if current_errors.none?

        message = current_errors.join("\n\n")
        Yast2::Popup.show(message, headline: :error)

        false
      end

    private

      # @return [Actions::Controllers::BtrfsDevices]
      attr_reader :controller

      # Widget to select the metadata RAID level
      #
      # @return [Widgets::BtrfsMetadataRaidLevel]
      def metadata_raid_level_widget
        @metadata_raid_level_widget ||= Widgets::BtrfsMetadataRaidLevel.new(controller)
      end

      # Widget to select the data RAID level
      #
      # @return [Widgets::BtrfsDataRaidLevel]
      def data_raid_level_widget
        @data_raid_level_widget ||= Widgets::BtrfsDataRaidLevel.new(controller)
      end

      # Widget to select devices used by the filesystem
      #
      # @return [Widgets::BtrfsDevicesSelector]
      def btrfs_devices_selector_widget
        @btrfs_devices_widget ||= Widgets::BtrfsDevicesSelector.new(controller)
      end

      # Btrfs RAID levels help
      #
      # @return [String]
      def help_for_raid_levels
        _("<h4><b>Btrfs RAID levels</b></h4>" \
          "<p> Btrfs supports the following RAID levels for both, metadata and data:" \
            "<ul>" \
              "<li>" \
                "<b>DUP:</b> stores two copies of each piece of data on the same device. " \
                "This is similar to RAID1, and protects against block-level errors on the device, " \
                "but does not provide any guarantees if the device fails. Only one device must be " \
                "be selected to use DUP." \
              "</li>" \
              "<li>" \
                "<b>SINGLE:</b> stores a single copy of each piece of data. Btrfs requires a minimum " \
                "of one device to use SINGLE." \
              "</li>" \
              "<li>" \
                "<b>RAID0:</b> provides no form of error recovery, but stripes a " \
                "single copy of data across multiple devices for performance purpose. Btrfs requires " \
                "a minimum of two devices to use RAID0." \
              "</li>" \
              "<li>" \
                "<b>RAID1:</b> stores two complete copies of each piece of data. " \
                "Each copy is stored on a different device. Btrfs requires a minimum of two devices " \
                "to use RAID1." \
              "</li>" \
              "<li>" \
                "<b>RAID10:</b> stores two complete copies of each piece of data, and also stripes " \
                "each copy across multiple devices for performance. Btrfs requires a minimum of five " \
                "devices to use RAID10" \
              "</li>" \
            "</ul>" \
          "</p>")
      end

      # Btrfs default RAID level help
      #
      # @return [String]
      def help_for_default_raid_level
        _("<p>" \
            "When <b>DEFAULT</b> RAID level is used, Btrfs will select a RAID level depending on " \
            "whether the filesystem is being created on top of multiple devices or using only one " \
            "device. For a single-device Btrfs, the tool also will distinguish between rotational " \
            "or not-rotational devices to choose the default value." \
          "</p>")
      end

      # Errors for the selected values
      #
      # @return [Array<String>]
      def errors
        [
          metadata_devices_error,
          data_devices_error
        ].compact
      end

      # Error when the selected metadata RAID level cannot be used (according to the number of selected
      # devices)
      #
      # @return [String, nil] nil if there is no error
      def metadata_devices_error
        raid_level_devices_error(:metadata)
      end

      # Error when the selected data RAID level cannot be used (according to the number of selected
      # devices)
      #
      # @return [String, nil] nil if there is no error
      def data_devices_error
        raid_level_devices_error(:data)
      end

      # Helper method to get the metadata/data error according to the number of selected devices.
      #
      # @param data [:metadata, :data]
      # @return [String, nil]
      def raid_level_devices_error(data)
        return nil unless filesystem

        allowed_raid_levels = allowed_raid_levels(data)
        selected_raid_level = selected_raid_level(data)

        return nil if allowed_raid_levels.include?(selected_raid_level)

        format(
          _("According to the selected devices, only the following %{data}\n" \
            "RAID levels can be used: %{levels}."),
          data:   data.to_s,
          levels: allowed_raid_levels.map(&:to_human_string).join(", ")
        )
      end

      # RAID levels that can be used according to the selected devices
      #
      # @param data [:metadata, :data]
      # @return [Array<Y2Storage::BtrfsRaidLevel>]
      def allowed_raid_levels(data)
        controller.allowed_raid_levels(data)
      end

      # RAID level currently selected
      #
      # @param data [:metadata, :data]
      # @return [Y2Storage::BtrfsRaidLevel]
      def selected_raid_level(data)
        controller.send("#{data}_raid_level")
      end

      # Current filesystem
      #
      # @return [Y2Storage::Filesystems::Btrfs]
      def filesystem
        controller.filesystem
      end
    end
  end
end
