# Copyright (c) [2017-2019] SUSE LLC
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
require "y2partitioner/dialogs/base"
require "y2partitioner/widgets/encrypt"
require "y2partitioner/widgets/controller_radio_buttons"

module Y2Partitioner
  module Dialogs
    # Ask for the concrete action to perform when the goal is to obtain an
    # encrypted device, including details like the password.
    # Part of {Actions::AddPartition} and {Actions::EditBlkDevice}.
    # Formerly MiniWorkflowStepPassword
    class Encryption < Base
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
      end

      # @macro seeDialog
      def title
        @controller.wizard_title
      end

      # @macro seeDialog
      def contents
        main_widget =
          if @controller.actions.include?(:keep)
            ActionWidget.new(@controller)
          else
            Widgets::Encrypt.new(@controller)
          end

        HVSquash(main_widget)
      end

      # Internal widget used when both :keep and :encrypt options are possible
      class ActionWidget < Widgets::ControllerRadioButtons
        # @param controller [Actions::Controllers::Encryption]
        #   a controller collecting data for managing the encryption of a device
        def initialize(controller)
          textdomain "storage"
          @controller = controller
        end

        # @macro seeAbstractWidget
        def label
          _("Choose an Action")
        end

        # @macro seeItemsSelection
        def items
          keep_label =
            format(_("Preserve existing encryption (%s)"), encryption_method.to_human_string)

          [
            [:keep, keep_label],
            [:encrypt, _("Encrypt the device (replaces current encryption)")]
          ]
        end

        # @see Widgets::ControllerRadioButtons
        def widgets
          @widgets ||= [
            CWM::Empty.new("empty"),
            Widgets::Encrypt.new(@controller)
          ]
        end

        # @macro seeAbstractWidget
        def init
          self.value = @controller.action
          # trigger disabling the other subwidgets
          handle("ID" => value)
        end

        # @macro seeAbstractWidget
        def store
          current_widget.store if current_widget.respond_to?(:store)
          @controller.action = value
        end

        # @macro seeAbstractWidget
        def help
          # helptext
          _(
            "<p>Choose the encryption layer.</p>\n" \
            "<p>The device is already encrypted in the system, it's possible " \
            "to preserve the existing encryption layer or " \
            "to re-encrypt it with new settings.</p>"
          )
        end

        private

        # Encryption method currently used by the device
        #
        # @return [Y2Storage::EncryptionMethod]
        def encryption_method
          @controller.encryption.method
        end
      end
    end
  end
end
