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
      class SelectRootDisk < Base
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
                *([any_disk_widget] + candidate_disks.map { |d| disk_widget(d) })
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

        def any_disk_widget
          Left(RadioButton(Id(:any), _("Any disk")))
        end

        def disk_widget(disk)
          Left(RadioButton(Id(disk.name), disk_label(disk)))
        end

        def initialize_widgets
          widget = settings.root_device || :any
          widget_update(widget, true)
        end

        def update_settings!
          root = candidate_disks.detect { |d| widget_value(d.name) }
          settings.root_device = root ? root.name : nil
          true
        end

      private

        def candidate_disks
          return @candidate_disks if @candidate_disks
          candidates = settings.candidate_devices || []
          @candidate_disks = candidates.map { |d| analyzer.device_by_name(d) }
        end
      end
    end
  end
end
