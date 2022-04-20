# Copyright (c) [2017-2020] SUSE LLC
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

module Y2Partitioner
  module Dialogs
    # Adapt CWM dialog to allow popup dialogs
    class Popup < Base
      def wizard_create_dialog(&block)
        Yast::UI.OpenDialog(layout)
        block.call
      ensure
        Yast::UI.CloseDialog()
      end

      def should_open_dialog?
        true
      end

      def layout
        MarginBox(
          1, # left / right
          0.45, # top / bottom
          VBox(
            # This Id makes the Help texts work, see Wizard.SetHelpText
            Id(:WizardDialog),
            Left(Heading(Id(:title), title)),
            VSpacing(0.6),
            VCenter(MinSize(min_width, min_height, ReplacePoint(Id(:contents), Empty()))),
            VSpacing(0.45),
            # relaxSanityCheck is needed to allow [OK] [Help] without [Cancel]
            ButtonBox(Opt(:relaxSanityCheck), *buttons)
          )
        )
      end

      protected

      # Popup min width
      #
      # @return [Integer]
      def min_width
        50
      end

      # Popup min height
      #
      # @return [Integer]
      def min_height
        14
      end

      def ok_button_label
        Yast::Label.OKButton
      end

      def cancel_button_label
        Yast::Label.CancelButton
      end

      def buttons
        [ok_button, cancel_button, help_button]
      end

      def help_button
        PushButton(Id(:help), Opt(:helpButton), Yast::Label.HelpButton)
      end

      def ok_button
        PushButton(Id(:ok), Opt(:default), ok_button_label)
      end

      def cancel_button
        PushButton(Id(:cancel), cancel_button_label)
      end
    end
  end
end
