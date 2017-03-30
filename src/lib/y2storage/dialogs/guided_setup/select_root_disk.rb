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
      # Dialog for root disk selection.
      class SelectRootDisk < Dialogs::GuidedSetup::Base
      protected

        def label
          "Guided Setup - step 2"
        end

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
                *disks_data.map { |d| disk_widget(d) }
              )
            )
          )
        end

        def windows_actions_widget
          VBox(
            Left(Label(_("Choose what to do with existing Windows systems"))),
            Left(
              ComboBox(
                Id(:windows_action), "",
                [
                  Item(Id(:not_modify), _("Do not modify")),
                  Item(Id(:resize), _("Resize if needed")),
                  Item(Id(:remove), _("Remove if needed")),
                  Item(Id(:always_remove), _("Remove even if not needed"))
                ]
              )
            )
          )
        end

        def linux_actions_widget
          VBox(
            Left(Label(_("Choose what to do with existing Linux partitions"))),
            Left(
              ComboBox(
                Id(:linux_action), "",
                [
                  Item(Id(:not_modify), _("Do not modify")),
                  Item(Id(:remove), _("Remove if needed")),
                  Item(Id(:always_remove), _("Remove even if not needed"))
                ]
              )
            )
          )
        end

        def initialize_widgets
          id = disks_data.first[:name]
          widget_update(id, true)
        end

        def update_settings!
          root = disks.first { |d| widget_value(d) }
          settings.root_device = root
        end

        def disks
          settings.candidate_devices
        end

        def disks_data
          super.select { |d| disks.include?(d[:name]) }
        end

      private

        def disk_widget(disk_data)
          Left(RadioButton(Id(disk_data[:name]), disk_data[:label]))
        end
      end
    end
  end
end
