# Copyright (c) [2021] SUSE LLC
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

require "yast/i18n"
require "yast2/popup"
require "y2partitioner/unmounter"

module Y2Partitioner
  module Dialogs
    # Dialog for unmounting devices
    #
    # It is intended to be used by some actions, for example, when deleting or resizing a device.
    #
    # @note This is not a CWM dialog. It only consists on a convenient wrapper that invokes some popups.
    class Unmount
      include Yast::I18n

      # Constructor
      #
      # @param devices [Array<Y2Storage::Mountable>] devices to unmount
      # @param note [String, nil] option note to include in the dialog
      # @param allow_continue [Boolean] whether the dialog should allow to continue without unmounting
      def initialize(*devices, note: nil, allow_continue: true)
        textdomain "storage"

        @devices = devices.flatten
        @note = note
        @allow_continue = allow_continue
      end

      # Shows a popup asking for unmounting the devices
      #
      # The user can select to unmount, to continue without unmounting (see {#allow_continue?}), or to
      # cancel.
      #
      # The devices are unmounted when the user selects to unmount (see {#unmount_devices}). In case of
      # unmounting errors, the user is informed by means of another popup.
      #
      # @return [:finish, :cancel]
      def run
        # FIXME: This check is here to avoid changes in installer behaviour for GA. The dialog for
        #   unmounting devices will be only shown in normal mode. This check can be removed after GA.
        return :finish unless Yast::Mode.normal

        loop do
          case show
          when :unmount
            unmount_devices
            break :finish if errors.none?

            errors_popup
          when :continue
            break :finish
          when :cancel
            break :cancel
          end
        end
      end

      private

      # All the devices to unmount
      #
      # @return [Array<Y2Storage::Mountable>]
      attr_reader :devices

      # Optional note to include in the dialog
      #
      # @return [String, nil]
      attr_reader :note

      # Whether to continue without unmounting is allowed
      #
      # @return [Boolean]
      attr_reader :allow_continue
      alias_method :allow_continue?, :allow_continue

      # Errors when trying to unmount devices
      #
      # @return [Array<String>]
      def errors
        @errors ||= []
      end

      # Devices successfully unmounted
      #
      # @return [Array<Y2Storage::Mountable>]
      def unmounted_devices
        @unmounted_devices ||= []
      end

      # Devices pending to be unmounted
      #
      # @return [Array<Y2Storage::Mountable>]
      def mounted_devices
        devices - unmounted_devices
      end

      # Unmounts the devices
      #
      # Errors are stored when some devices cannot be unmounted, see {#errors}.
      def unmount_devices
        @errors = []

        mounted_devices.each { |d| unmount_device(d) }
      end

      # Unmounts a given device
      #
      # @see Unmounter
      #
      # An error is stored when the device cannot be unmounted.
      #
      # @param device [Y2Storage::Mountable]
      def unmount_device(device)
        unmounter = Unmounter.new(device)
        unmounter.unmount

        if unmounter.error?
          errors << unmounter.error
        else
          unmounted_devices << device
        end
      end

      # Shows the popup asking for unmounting devices
      #
      # @return [Symbol]
      def show
        Yast2::Popup.show(content, headline: Yast::Label.WarningMsg, buttons:, focus: :cancel)
      end

      # Content for the popup
      #
      # It includes information about the mounted devices and an optional note, see {#note}.
      #
      # @return [String]
      def content
        # TRANSLATORS: %{mount_sentences} is replaced by a text describing which devices are mounted.
        #   Try to keep line breaks.
        text = format(_("The following devices are currently mounted:\n\n%{mount_sentences}\n\n"),
          mount_sentences:)

        text << (note + "\n\n") if note

        text <<
          if allow_continue?
            _("You can try to unmount now, continue without unmounting or cancel.\n" \
              "Click Cancel unless you know exactly what you are doing.")
          else
            _("You can try to unmount now or cancel.\n" \
              "Click Cancel unless you know exactly what you are doing.")
          end

        text
      end

      # Sentences describing the mounted devices, each sentence in a separate line.
      #
      # @return [String]
      def mount_sentences
        mounted_devices.map { |d| mount_sentence(d) }.join("\n")
      end

      # Sentence describing a mounted device
      #
      # @param device [Y2Storage::Mountable]
      # @return [String]
      def mount_sentence(device)
        # TRANSLATORS: %{device} is replaced by a device name (e.g., /dev/sda1) and %{mount_point}
        #   is replaced by a mount path (e.g., /home).
        format(_("%{name} mounted at %{mount_point}"),
          name:        device_name(device),
          mount_point: device.mount_point.path)
      end

      # Generates the label for a given device
      #
      # @param device [Y2Storage::Mountable]
      # @return [String]
      def device_name(device)
        return btrfs_subvolume_name(device) if device.is?(:btrfs_subvolume)

        device = device.blk_devices.first if device.is?(:blk_filesystem) && !device.multidevice?

        device.display_name
      end

      # Generates the label for a Btrfs subvolume
      #
      # @param subvolume [Y2Storage::BtrfsSubvolume]
      # @return [String]
      def btrfs_subvolume_name(subvolume)
        # TRANSLATORS: %{path} is replaced by a Btrfs subvolume path (e.g., @home).
        format(_("Btrfs subvolume %{path}"), path: subvolume.path)
      end

      # Buttons to show in the dialog
      #
      # @return [Hash<Symbol, String>]
      def buttons
        buttons = {}

        buttons[:continue] = Yast::Label.ContinueButton if allow_continue?
        buttons[:cancel] = Yast::Label.CancelButton
        buttons[:unmount] = _("Unmount")

        buttons
      end

      # Shows a popup to inform about unmounting errors
      def errors_popup
        # TRANSLATORS: %{mount_sentences} is replaced by a text describing which devices are mounted.
        #   Try to keep line breaks.
        content = format(_("Some devices cannot be unmounted: \n\n%{mount_sentences}"),
          mount_sentences:)

        details = errors.join("\n\n-------\n\n")

        Yast2::Popup.show(content, headline: :error, details:, buttons: :ok)
      end
    end
  end
end
