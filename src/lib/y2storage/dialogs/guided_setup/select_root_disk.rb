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
      class SelectRootDisk < Dialogs::GuidedSetup::Base

        def label
          "Guided Setup - step 2"
        end

      protected

        def dialog_title
          _("Select Hard Disk(s)")
        end

        def dialog_content
          HSquash(
            VBox(
              root_selection_widget,
              VSpacing(1),
              windows_actions_widget,
              VSpacing(1),
              linux_actions_widget
            )
          )
        end

        def root_selection_widget
          VBox(
            Left(Label(_("Please select a disk to use as the \"root\" partition (/)"))),
            VSpacing(0.3),
            RadioButtonGroup(
              Id(:root_disk),
              VBox(
                Left(RadioButton(Id(:disk1), "/dev/sda", true)),
                Left(RadioButton(Id(:disk1), "/dev/sdb", false))
              )
            )
          )
        end

        def windows_actions_widget
          VBox(
            Left(Label(_("Choose what to do with existing Windows systems"))),
            Left(ComboBox(Id(:windows_action), "",
              [
                "Do not modify",
                "Resize if needed",
                "Remove if needed",
                "Remove even if not needed"
              ])
            )
          )
        end

        def linux_actions_widget
          VBox(
            Left(Label(_("Choose what to do with existing Linux partitions"))),
            Left(ComboBox(Id(:linux_action), "",
              [
                "Do not modify",
                "Remove if needed",
                "Remove even if not needed"
              ])
            )
          )
        end

        def create_dialog
          super
          true
        end
      end
    end
  end
end
