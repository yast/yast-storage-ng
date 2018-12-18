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

Yast.import "HTML"

module Y2Partitioner
  # Mixin for confimation when recursive deletion is performed
  module ConfirmRecursiveDelete
    include Yast::UIShortcuts

  private

    # Helpful method to show a descriptive confirm message with all affected devices
    #
    # @param devices [Array<Y2Storage::Device>, Y2Storage::Device] devices to delete
    # @param headline [String]
    # @param label_before [String]
    # @param label_after [String]
    # @return [Boolean]
    def confirm_recursive_delete(devices, headline, label_before, label_after)
      button_box = ButtonBox(
        PushButton(Id(:yes), Opt(:okButton), recursive_delete_yes_label),
        PushButton(
          Id(:no_button),
          Opt(:default, :cancelButton),
          recursive_delete_no_label
        )
      )

      fancy_question(headline,
        label_before,
        Yast::HTML.List(devices_to_delete(devices).sort),
        label_after,
        button_box)
    end

    # @param headline [String]
    # @param label_before [String]
    # @param rich_text [String]
    # @param label_after [String]
    # @param button_term [Yast::UI::Term]
    # @return [Boolean]
    def fancy_question(headline, label_before, rich_text, label_after, button_term)
      layout = VBox(
        VSpacing(0.4),
        HBox(
          Top(Yast::Icon.Simple("question")),
          HSpacing(1),
          VBox(
            Left(Heading(headline)),
            VSpacing(0.2),
            Left(Label(label_before)),
            VSpacing(0.2),
            Left(RichText(rich_text)),
            VSpacing(0.2),
            Left(Label(label_after)),
            button_term
          )
        )
      )

      Yast::UI.OpenDialog(layout)
      ret = Yast::UI.UserInput
      Yast::UI.CloseDialog

      ret == :yes
    end

    # Label of the button to confirm in {#confirm_recursive_delete}
    #
    # @return [String]
    def recursive_delete_yes_label
      Yast::Label.DeleteButton
    end

    # Label of the button to cancel in {#confirm_recursive_delete}
    #
    # @return [String]
    def recursive_delete_no_label
      Yast::Label.CancelButton
    end

    # All devices holded by the devices to delete
    #
    # @param devices [Array<Y2Storage::Device>] devices to delete
    # @return [Array<Y2Storage::Device>]
    def devices_to_delete(*devices)
      devices.flatten.map { |d| dependent_devices(d) }.flatten
    end

    # Devices that depends on a device to delete
    #
    # For example, a Vg depends on some partitions used as physical volumes,
    # so the vg should be deleted when one of that partitions is deleted.
    #
    # This method obtains the name of all devices that should be deleted when
    # the given device is deleted. This info is useful for some confirm messages.
    #
    # @param device [Y2Storage::Device] device to delete
    # @return [Array<String>] name of dependent devices
    def dependent_devices(device)
      device.descendants.map do |dev|
        dev.name if dev.respond_to?(:name)
      end.compact
    end
  end
end
