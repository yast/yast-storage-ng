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
require "y2partitioner/device_graphs"

module Y2Partitioner
  # Mixin that offers a dialog to immediate unmount a block device
  #
  # @note This feature is intended to allow to unmount devices before the commit phase, for example,
  #   when a device is deleted or resized. But there are serveral scenarios where the actions require
  #   unmount the device and the user is not asked for it. For instance, when a new partition table
  #   is created over a disk and some of its partitions are already mounted.
  module ImmediateUnmount
    include Yast::Logger
    include Yast::I18n

  private

    # Sets textdomain
    def included(_target)
      textdomain "storage"
    end

    # Shows a Popup dialog to try to unmount the device
    #
    # @param device [Y2Storage::BlkDevice]
    # @param full_message [String, nil] message to show in the dialog (param note would be ignored)
    # @param note [String, nil] note to add to the generic message (ignored if full_message is used)
    # @param allow_continue [Boolean] if it should allow to continue without unmounting
    #
    # @return [Boolean]
    def immediate_unmount(device, full_message: nil, note: nil, allow_continue: true)
      loop do
        case confirm_unmount(device, full_message, note, allow_continue)
        when :unmount
          break true if unmount(device)
        when :continue
          break true
        when :cancel
          break false
        end
      end
    end

    # Popup dialog for immediate unmounting
    #
    # @param device [Y2Storage::BlkDevice]
    # @param full_message [String, nil] message to show in the dialog (param note would be ignored)
    # @param note [String, nil] note to add to the generic message (ignored if full_message is used)
    # @param allow_continue [Boolean] if it should allow to continue without unmounting
    def confirm_unmount(device, full_message, note, allow_continue)
      headline = Yast::Label.WarningMsg

      message = immediate_unmount_message(device, full_message, note, allow_continue)

      buttons = inmmediate_unmount_buttons(allow_continue)

      Yast2::Popup.show(message, headline: headline, buttons: buttons, focus: :cancel)
    end

    # Performs the unmount action
    #
    # @note An error message is shown when the device cannot be unmounted.
    #
    # @param device [Y2Storage::BlkDevice]
    # @return [Boolean] true if the device was correctly unmounted; false otherwise.
    def unmount(device)
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

    # Message for the immediate unmount dialog
    #
    # @note The message depends on several aspects:
    #   * If the full_message param is provided, the dialog message is the full_message value.
    #   * If a note is provided, a generic message is generated including that note.
    #   * If continue is not allowed, the generic message is properly adjusted.
    #
    # @param device [Y2Storage::BlkDevice]
    # @param full_message [String, nil] message to show in the dialog (param note would be ignored)
    # @param note [String, nil] note to add to the generic message (ignored if full_message is used)
    # @param allow_continue [Boolean] if it should allow to continue without unmounting
    #
    # @return [String]
    def immediate_unmount_message(device, full_message, note, allow_continue)
      return full_message unless full_message.nil?

      path = device.mount_point.path

      note = note.nil? ? "" : "\n" + note

      format(
        # TRANSLATORS: Generic message when trying to unmount a device. %{path} is replaced
        # by a mount point path (e.g., /home), %{note} is replaced by a specefic note to clarify
        # the action and %{options_message} is replaced by an explanation about possible actions
        # to peform in the dialog.
        _("The file system is currently mounted on %{path}.%{note}\n\n%{options_message}"),
        path:            path,
        note:            note,
        options_message: immediate_unmount_options_message(allow_continue)
      )
    end

    # Part of the generic message that explains the options
    #
    # @param allow_continue [Boolean] if it should allow to continue without unmounting
    # @return [String]
    def immediate_unmount_options_message(allow_continue)
      if allow_continue
        # TRANSLATORS: Actions explanation when continue is allowed.
        _("You can try to unmount it now, continue without unmounting or cancel.\n" \
          "In case you decide to continue, the file system will be automatically \n" \
          "unmounted when all changes are applied. Note that automatic unmount \n" \
          "could fail and, for this reason, it is recommendable to try to unmount now.\n" \
          "Click Cancel unless you know exactly what you are doing.")
      else
        # TRANSLATORS: Actions explanation when continue is not allowed.
        _("You can try to unmount it now or cancel.\n" \
          "Click Cancel unless you know exactly what you are doing.")
      end
    end

    # Buttons to show for the immediate unmount popup
    #
    # @param allow_continue [Boolean] if it should allow to continue without unmounting
    # @return [Hash<Symbol, String>]
    def inmmediate_unmount_buttons(allow_continue)
      buttons = {}

      buttons[:continue] = Yast::Label.ContinueButton if allow_continue
      buttons[:cancel] = Yast::Label.CancelButton
      buttons[:unmount] = _("Unmount")

      buttons
    end
  end
end
