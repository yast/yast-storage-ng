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
      # Calculates the proposal settings to be used in the next proposal attempt.
      class SelectRootDisk < Dialogs::GuidedSetup::Base
        # @return [ProposalSettings] settings specified by the user
        # attr_reader :settings

        def next_handler
          adjust_settings_to_mode
          super
        end

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
          init_widgets
          true
        end

        def init_widgets
          # Remember entered password
          Yast::UI.ChangeWidget(Id(:encryption_password), :Value, settings.encryption_password)
        end

        def partition_selected?
          !settings.use_lvm
        end

        def lvm_selected?
          settings.use_lvm && settings.encryption_password.nil?
        end

        def encrypted_selected?
          settings.use_lvm && !settings.encryption_password.nil?
        end

        def adjust_settings_to_mode
          case Yast::UI.QueryWidget(Id(:mode), :CurrentButton)
          when :mode_partition
            settings.use_lvm = false
            settings.encryption_password = nil
          when :mode_lvm
            settings.use_lvm = true
            settings.encryption_password = nil
          when :mode_encrypted
            settings.use_lvm = true
            settings.encryption_password = Yast::UI.QueryWidget(Id(:encryption_password), :Value)
          end
        end
      end
    end
  end
end
