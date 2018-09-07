# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "yast/i18n"
require "yast2/popup"

module Y2Partitioner
  # Mixin that offers a dialog to immediate unmount a block device
  #
  # @note This feature is intended to allow to unmount devices before the commit phase, for example,
  #   when a device is deleted or resized. But there are serveral scenarios where the actions require
  #   unmount the device and the user is not asked for it. For instance, when a new partition table
  #   is created over a disk and some of its partitions are already mounted.
  module ImmediateUnmount
    # Shows a Popup dialog to try to unmount the device
    #
    # @param device [Y2Storage::BlkDevice]
    # @param full_message [String, nil] message to show in the dialog (param note would be ignored)
    # @param note [String, nil] note to add to the generic message (ignored if full_message is used)
    # @param allow_continue [Boolean] if it should allow to continue without unmounting
    #
    # @return [Boolean]
    def immediate_unmount(device, full_message: nil, note: nil, allow_continue: true)
      Unmounter.new(device, full_message, note, allow_continue).unmount
    end

    # Utility class for immediate unmounting a device
    class Unmounter
      include Yast::Logger
      include Yast::I18n

      # Constructor
      #
      # @param device [Y2Storage::BlkDevice]
      # @param full_message [String, nil] message to show in the dialog (param note would be ignored)
      # @param note [String, nil] note to add to the generic message (ignored if full_message is used)
      # @param allow_continue [Boolean] if it should allow to continue without unmounting
      def initialize(device, full_message, note, allow_continue)
        textdomain "storage"

        @device = device
        @full_message = full_message
        @note = note
        @allow_continue = allow_continue
      end

      # Shows a dialog to unmount a device and performs the action if the user selects to unmount
      #
      # @return [Boolean] true if the user decides to continue without unmounting (when to continue
      #   is allowed) or the device was correctly unmounted; false if the user cancels.
      def unmount
        loop do
          case unmount_dialog
          when :unmount
            break true if unmount_device
          when :continue
            break true
          when :cancel
            break false
          end
        end
      end

    private

      # @return [Y2Storage::BlkDevice]
      attr_reader :device

      # @return [String, nil] message to show in the dialog (note would be ignored)
      attr_reader :full_message

      # @return [String, nil] note to add to the generic message (ignored if full_message is used)
      attr_reader :note

      # @return [Boolean] if it should allow to continue without unmounting
      attr_reader :allow_continue

      # Popup dialog for immediate unmounting
      #
      # @return [Yast2::Popup]
      def unmount_dialog
        Yast2::Popup.show(message, headline: headline, buttons: buttons, focus: :cancel)
      end

      # Dialog headline
      #
      # @return [String]
      def headline
        Yast::Label.WarningMsg
      end

      # Message for the unmount dialog
      #
      # @note The message depends on several aspects:
      #   * If full_message was provided, the dialog message is the full_message value.
      #   * If a note was provided, a generic message is generated including that note.
      #   * If continue is not allowed, the generic message is properly adjusted.
      #
      # @return [String]
      def message
        return full_message unless full_message.nil?

        format(
          # TRANSLATORS: Generic message when trying to unmount a device. %{path} is replaced
          # by a mount point path (e.g., /home), %{note} is replaced by a specefic note to clarify
          # the action and %{options_message} is replaced by an explanation about possible actions
          # to peform in the dialog.
          _("The file system is currently mounted on %{mount_point}.%{note}\n\n%{options_message}"),
          mount_point:     mount_point,
          note:            note_message,
          options_message: options_message
        )
      end

      # Mount point path of the device to unmount
      #
      # @return [String]
      def mount_point
        device.mount_point.path
      end

      # Prepare the note to be included in the message
      #
      # @return [String]
      def note_message
        note.nil? ? "" : "\n" + note
      end

      # Part of the generic message that explains the options
      #
      # @return [String]
      def options_message
        if allow_continue
          # TRANSLATORS: Actions explanation when continue is allowed.
          _("You can try to unmount it now, continue without unmounting or cancel.\n" \
            "In case you decide to continue, the file system will be automatically \n" \
            "unmounted when all changes are applied. Note that automatic unmount \n" \
            "could fail and, for this reason, it is recommended to try to unmount now.\n" \
            "Click Cancel unless you know exactly what you are doing.")
        else
          # TRANSLATORS: Actions explanation when continue is not allowed.
          _("You can try to unmount it now or cancel.\n" \
            "Click Cancel unless you know exactly what you are doing.")
        end
      end

      # Buttons to show for the immediate unmount popup
      #
      # @return [Hash<Symbol, String>]
      def buttons
        buttons = {}

        buttons[:continue] = Yast::Label.ContinueButton if allow_continue
        buttons[:cancel] = Yast::Label.CancelButton
        buttons[:unmount] = _("Unmount")

        buttons
      end

      # Performs the unmount action
      #
      # @note An error message is shown when the device cannot be unmounted.
      #
      # @return [Boolean] true if the device was correctly unmounted; false otherwise.
      def unmount_device
        device.mount_point.immediate_deactivate
        true
      rescue Storage::Exception => e
        log.warn "failed to unmount #{device.name}: #{e.what}"

        show_unmount_error(e.what)
        false
      end

      # Error popup showed when the device cannot be unmounted
      #
      # @param details [String] error details
      def show_unmount_error(details)
        # TRANSLATORS: Error message when the device could not be unmounted
        message = _("The file system could not be unmounted")

        Yast2::Popup.show(message, headline: :error, details: details, buttons: :ok)
      end
    end
  end
end
