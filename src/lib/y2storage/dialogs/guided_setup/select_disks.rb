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
      # Dialog for disks selection for the proposal.
      class SelectDisks < Dialogs::GuidedSetup::Base
      protected

        MAX_DISKS = 3

        def dialog_title
          _("Select Hard Disk(s)")
        end

        def dialog_content
          HSquash(
            VBox(
              Left(Label(_("Select one or more (max #{MAX_DISKS}) hard disks"))),
              VSpacing(0.3),
              *disks_data.map { |d| disk_widget(d) }
            )
          )
        end

        def disk_widget(disk_data)
          Left(CheckBox(Id(disk_data[:name]), disk_data[:label]))
        end

        def initialize_widgets
          selected = settings.candidate_devices || disks
          selected.first(MAX_DISKS).each { |id| widget_update(id, true) }
        end

        def update_settings!
          valid = valid_settings?
          settings.candidate_devices = selected_disks if valid
          valid
        end

      private

        def valid_settings?
          any_selected_disk? && !many_selected_disks?
        end

        def any_selected_disk?
          return true unless selected_disks.empty?
          Yast::Report.Warning(_("You have to select any disk"))
          false
        end

        def many_selected_disks?
          return false if selected_disks.size <= MAX_DISKS
          Yast::Report.Warning(_("Select max #{MAX_DISKS} disks"))
          true
        end

        def selected_disks
          disks.select { |d| widget_value(d) }
        end

        def disks
          disks_data.map { |d| d[:name] }
        end
      end
    end
  end
end
