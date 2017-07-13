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
require "ui/dialog"
require "y2storage/secret_attributes"

Yast.import "UI"

module Y2Storage
  module Dialogs
    module Callbacks
      # Dialog to manage luks activation callbacks
      class ActivateLuks < UI::Dialog
        include SecretAttributes

        secret_attr :encryption_password

        def initialize(uuid, attempt)
          textdomain "storage-ng"
          @uuid = uuid
          @attempt = attempt
        end

        def password_handler
          activate_button
        end

        def accept_handler
          self.encryption_password = password
          finish_dialog(:accept)
        end

        def cancel_handler
          finish_dialog(:cancel)
        end

        def dialog_content
          VBox(
            VSpacing(0.4),
            HBox(
              HSpacing(1),
              VBox(
                Left(Heading(_("Encrypted Volume Activation"))),
                VSpacing(0.2),
                *explanation_widgets,
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

      protected

        attr_reader :uuid, :attempt

        def create_dialog
          super
          activate_button
          true
        end

        def password
          Yast::UI.QueryWidget(Id(:password), :Value).to_s
        end

        def activate_button
          Yast::UI.ChangeWidget(Id(:accept), :Enabled, password.size > 0)
        end

        def explanation_widgets
          [
            Left(
              Label(
                _("The following device contains an encryption signature but the\n" \
                  "password is not yet known.")
              )
            ),
            VSpacing(0.2),
            Left(Label("UUID: #{uuid}")),
            VSpacing(0.2),
            Left(
              Label(
                _("The password is needed if the device contains a system to be\n" \
                  "updated or belongs to an LVM to be used during installation.")
              )
            )
          ]
        end
      end
    end
  end
end
