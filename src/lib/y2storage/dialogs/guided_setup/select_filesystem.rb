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
      class SelectFilesystem < Dialogs::GuidedSetup::Base

        def label
          "Guided Setup - step 4"
        end

        def next_handler
          update_settings
          super
        end

        def root_filesystem_handler
          widget_update(:snapshots, widget_value(:root_filesystem) == :btrfs, attr: :Enabled)
        end

        def separate_home_handler
          widget_update(:home_filesystem, widget_value(:separate_home), attr: :Enabled)
        end

      protected

        def create_dialog
          super
          initialize_widgets
          true
        end

        def dialog_title
          _("Filesystem Options")
        end

        def dialog_content
          HSquash(
            VBox(
              root_filesystem_widget,
              VSpacing(2),
              home_filesystem_widget
            )
          )
        end

        def root_filesystem_widget
          VBox(
            Left(
              ComboBox(Id(:root_filesystem), Opt(:notify), _("File System for Root Partition"),
                [
                  Item(Id(:btrfs), "BtrFS"),
                  Item(Id(:ext4), "Ext4"),
                  Item(Id(:xfs), "XFS")
                ]
              )
            ),
            Left(
              HBox(
                HSpacing(4),
                Left(CheckBox(Id(:snapshots), _("Enable Snapshots"), true))
              )
            )
          )
        end

        def home_filesystem_widget
          VBox(
            Left(
              CheckBox(Id(:separate_home), Opt(:notify), _("Propose Separate Home Partition"))
            ),
            Left(
              HBox(
                HSpacing(4),
                ComboBox(Id(:home_filesystem), _("File System for Home Partition"),
                  [
                    Item(Id(:btrfs), "BtrFS"),
                    Item(Id(:ext4), "Ext4"),
                    Item(Id(:xfs), "XFS")
                  ]
                )
              )
            )
          )
        end

      private

        def initialize_widgets
          initialize_root_filesystem_widget
          initialize_home_filesystem_widget
        end

        def initialize_root_filesystem_widget
          # filesystem = settings.root_filesystem || :btrfs
          # snapshots = settings.snapshots || true
          filesystem = :btrfs
          snapshots = true
          widget_update(:root_filesystem, filesystem)
          widget_update(:snapshots, snapshots)
        end

        def initialize_home_filesystem_widget
          # filesystem = settings.home_filesystem || :xfs
          # separate_home = settings.separate_home || true
          filesystem = :xfs
          separate_home = true
          widget_update(:home_filesystem, filesystem)
          widget_update(:separate_home, separate_home)
        end

        def update_settings
          true
        end
      end
    end
  end
end
