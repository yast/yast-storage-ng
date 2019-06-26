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
        def initialize(*params)
          textdomain "storage"
          super
        end

        # This dialog should be skipped when there is only one candidate
        # disk for installation and there are not installed systems.
        def skip?
          candidate_disks.size == 1 && all_partitions.empty?
        end

        # Before skipping, settings should be assigned.
        def before_skip
          settings.root_device = candidate_disks.first.name
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
              *(activate_windows_actions? ? [windows_action_widget, VSpacing(1)] : [Empty()]),
              linux_delete_mode_widget,
              VSpacing(1),
              other_delete_mode_widget
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

        def windows_action_widget
          VBox(
            Left(Label(_("Choose what to do with existing Windows systems"))),
            Left(
              ComboBox(
                Id(:windows_action), "",
                [
                  Item(Id(:not_modify), _("Do not modify")),
                  Item(Id(:resize), _("Resize if needed")),
                  Item(Id(:remove), _("Resize or remove as needed")),
                  Item(Id(:always_remove), _("Remove even if not needed"))
                ]
              )
            )
          )
        end

        def linux_delete_mode_widget
          VBox(
            Left(Label(_("Choose what to do with existing Linux partitions"))),
            Left(
              ComboBox(
                Id(:linux_delete_mode), "",
                [
                  Item(Id(:none), _("Do not modify")),
                  Item(Id(:ondemand), _("Remove if needed")),
                  Item(Id(:all), _("Remove even if not needed"))
                ]
              )
            )
          )
        end

        def other_delete_mode_widget
          VBox(
            Left(Label(_("Choose what to do with other partitions"))),
            Left(
              ComboBox(
                Id(:other_delete_mode), "",
                [
                  Item(Id(:none), _("Do not modify")),
                  Item(Id(:ondemand), _("Remove if needed")),
                  Item(Id(:all), _("Remove even if not needed"))
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

          widget_update(:windows_action, windows_action) if activate_windows_actions?

          widget_update(:linux_delete_mode, settings.linux_delete_mode)
          widget_update(:linux_delete_mode, activate_linux_delete_mode?, attr: :Enabled)

          widget_update(:other_delete_mode, settings.other_delete_mode)
          widget_update(:other_delete_mode, activate_other_delete_mode?, attr: :Enabled)
        end

        def update_settings!
          root = selected_disk
          settings.root_device = root ? root.name : nil

          settings.linux_delete_mode = widget_value(:linux_delete_mode)
          settings.other_delete_mode = widget_value(:other_delete_mode)

          update_windows_settings if activate_windows_actions?
        end

        def help_text
          # TRANSLATORS: Help text for root disk selection
          msg = _(
            "<p>" \
            "Select the disk where to create the root filesystem. " \
            "</p><p>" \
            "This is also the disk where boot-related partitions " \
            "will typically be created as necessary: /boot, ESP (EFI System " \
            "Partition), BIOS-Grub. " \
            "That means that this disk should be usable by the machine's " \
            "BIOS / firmware." \
            "</p><p>" \
            "In this dialog you can also choose what to do with existing partitions:" \
            "</p><p>" \
            "<ul>" \
            "<li>Do not modify (keep them as they are)</li>" \
            "<li>Remove if needed</li>" \
            "<li>Remove even if not needed (always remove)</li>" \
            "</ul>"
          )

          # TRANSLATORS: Help text for root disk selection, continued
          if activate_windows_actions?
            msg += _(
              "<ul>" \
              "<li>Resize if needed (Windows partitions only)</li>" \
              "<li>Resize or remove if needed (Windows partitions only)</li>" \
              "</ul>" \
              "<p>" \
              "That last option means to try to resize the Windows partition(s) to " \
              "make enough disk space available for Linux, but if that is not " \
              "enough, completely delete the Windows partition." \
              "</p>"
            )
          end

          msg
        end

        private

        def update_windows_settings
          case widget_value(:windows_action)
          when :not_modify
            settings.resize_windows = false
            settings.windows_delete_mode = :none
          when :resize
            settings.resize_windows = true
            settings.windows_delete_mode = :none
          when :remove
            settings.resize_windows = true
            settings.windows_delete_mode = :ondemand
          when :always_remove
            settings.resize_windows = false
            settings.windows_delete_mode = :all
          end
        end

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
          !windows_partitions.empty?
        end

        def activate_linux_delete_mode?
          !linux_partitions.empty?
        end

        def activate_other_delete_mode?
          all_partitions.size > linux_partitions.size + windows_partitions.size
        end

        def linux_partitions
          analyzer.linux_partitions(*candidate_disks)
        end

        def windows_partitions
          analyzer.windows_partitions(*candidate_disks)
        end

        def all_partitions
          @all_partitions ||= candidate_disks.map(&:partitions).flatten
        end

        def windows_action
          if settings.windows_delete_mode == :all
            :always_remove
          elsif settings.windows_delete_mode == :ondemand
            :remove
          elsif settings.resize_windows
            :resize
          else
            :not_modify
          end
        end
      end
    end
  end
end
