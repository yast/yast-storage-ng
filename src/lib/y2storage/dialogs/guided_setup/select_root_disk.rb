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
        # This dialog should be skipped when there is only one candidate
        # disk for installation and there are not installed systems.
        def skip?
          candidate_disks.size == 1 &&
            analyzer.installed_systems(candidate_disks.first).size == 0
        end

        # Before skipping, settings should be assigned.
        def before_skip
          settings.root_device = candidate_disks.first.name
        end

        def root_disk_handler
          widget_update(:windows_actions, activate_windows_actions?, attr: :Enabled)
          widget_update(:linux_actions, activate_linux_actions?, attr: :Enabled)
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
            if need_to_select_disk?
              RadioButtonGroup(
                Id(:root_disk),
                VBox(
                  *([any_disk_widget] + candidate_disks.map { |d| disk_widget(d) })
                )
              )
            else
              Left(Label(disk_label(candidate_disks.first)))
            end
          )
        end

        def windows_actions_widget
          VBox(
            Left(Label(_("Choose what to do with existing Windows systems"))),
            Left(
              ComboBox(
                Id(:windows_actions), "",
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
                Id(:linux_actions), "",
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
          Left(RadioButton(Id(:any_disk), _("Any disk")))
        end

        def disk_widget(disk)
          Left(RadioButton(Id(disk.name), disk_label(disk)))
        end

        def initialize_widgets
          # Select a root disk or any option
          widget = settings.root_device || :any_disk
          widget_update(widget, true)
          root_disk_handler
        end

        def update_settings!
          root = selected_disk
          settings.root_device = root ? root.name : nil
        end

      private

        def candidate_disks
          return @candidate_disks if @candidate_disks
          candidates = settings.candidate_devices || []
          @candidate_disks = candidates.map { |d| analyzer.device_by_name(d) }
        end

        def need_to_select_disk?
          candidate_disks.size > 1
        end

        def selected_disk
          if need_to_select_disk?
            candidate_disks.detect { |d| widget_value(d.name) }
          else
            candidate_disks.first
          end
        end

        def activate_windows_actions?
          !analyzer.windows_systems(*candidate_disks).empty?
        end

        def activate_linux_actions?
          !analyzer.linux_systems(*candidate_disks).empty?
        end
      end
    end
  end
end
