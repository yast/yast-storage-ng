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
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

require "yast"
require "y2storage"
require "y2storage/dialogs/guided_setup/base"

module Y2Storage
  module Dialogs
    class GuidedSetup
      class SelectScheme < Dialogs::GuidedSetup::Base

        def label
          "Guided Setup - step 3"
        end

        def encryption_handler
          widget_update(:password, widget_value(:encryption), attr: :Enabled)
          widget_update(:repeat_password, widget_value(:encryption), attr: :Enabled)
        end

      protected

        def dialog_title
          _("Partitioning Scheme")
        end

        def dialog_content
          HSquash(
            VBox(
              Left(CheckBox(Id(:lvm), _("Enable Logical Volume Management (LVM)"))),
              VSpacing(1),
              Left(CheckBox(Id(:encryption), Opt(:notify), _("Enable Disk Encryption"))),
              VSpacing(0.2),
              Left(
                HBox(
                  HSpacing(4),
                  Password(Id(:password), _("Password"))
                )
              ),
              Left(
                HBox(
                  HSpacing(4),
                  Password(Id(:repeat_password), _("Verify Password"))
                )
              )
            )
          )
        end

        def initialize_widgets
          widget_update(:lvm, settings.use_lvm)
          widget_update(:encryption, settings.use_encryption)
          encryption_handler
        end
      end
    end
  end
end
