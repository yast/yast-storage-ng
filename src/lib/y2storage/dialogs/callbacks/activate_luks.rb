#!/usr/bin/env ruby
#
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

Yast.import "UI"

module Y2Storage
  module Dialogs
    module Callbacks
      # Dialog to manage luks activation callbacks
      class ActivateLuks
        include Yast::UIShortcuts
        include Yast::I18n

        attr_reader :encryption_password

        def initialize(uuid, attempt)
          @uuid = uuid
          @attempt = attempt
        end

        def run
          create_dialog

          result = loop do
            input = Yast::UI.UserInput
            case input
            when :password
              activate_button
            when :accept
              @encryption_password = password
              break input
            when :cancel, :abort
              break input
            end
          end

          Yast::UI.CloseDialog
          result
        end

      protected

        attr_reader :uuid, :attempt

        def create_dialog
          Yast::UI.OpenDialog(dialog_content)
          activate_button
        end

        # rubocop:disable  Metrics/MethodLength
        def dialog_content
          VBox(
            VSpacing(0.4),
            HBox(
              HSpacing(1),
              VBox(
                Left(Heading(_("Encrypted Volume Activation"))),
                VSpacing(0.2),
                Left(
                  Label(
                    _("The following device contain an encryption signature but the \n" \
                        "password is not yet known.")
                  )
                ),
                VSpacing(0.2),
                Left(Label("UUID: #{uuid}")),
                VSpacing(0.2),
                Left(
                  Label(
                    _("The password need to be known if the device is needed either \n" \
                        "during an update or if it contains an encrypted volume.")
                  )
                ),
                VSpacing(0.2),
                Left(Label(_("Do you want to provide the encryption password?"))),
                Left(Password(Id(:password), Opt(:notify), _("Enter Encryption Password"))),
                ButtonBox(
                  PushButton(Id(:cancel), Yast::Label.CancelButton),
                  PushButton(Id(:accept), Yast::Label.OKButton)
                )
              )
            )
          )
        end
        # rubocop:enable all

        def password
          Yast::UI.QueryWidget(Id(:password), :Value).to_s
        end

        def activate_button
          Yast::UI.ChangeWidget(Id(:accept), :Enabled, password.size > 0)
        end
      end
    end
  end
end
