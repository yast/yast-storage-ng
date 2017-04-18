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
      class SelectDisks < Base
        # This dialog has to be skipped when there is only
        # one candidate disk for installing.
        def skip?
          analyzer.candidate_disks.size == 1
        end

        # Before skipping, settings should be assigned.
        def before_skip
          settings.candidate_devices = analyzer.candidate_disks.map(&:name)
        end

      protected

        MAX_DISKS = 3

        def dialog_title
          _("Select Hard Disk(s)")
        end

        def dialog_content
          HSquash(
            VBox(
              Left(Label(_("Select one or more (max %d) hard disks") % MAX_DISKS)),
              VSpacing(0.3),
              *all_disks.map { |d| disk_widget(d) }
            )
          )
        end

        def disk_widget(disk)
          Left(CheckBox(Id(disk.name), disk_label(disk)))
        end

        def initialize_widgets
          default_selected = settings.candidate_devices || []
          default_selected = default_selected.map { |d| analyzer.device_by_name(d) }
          default_selected = all_disks if default_selected.empty?
          default_selected.first(MAX_DISKS).each { |d| widget_update(d.name, true) }
        end

        def update_settings!
          settings.candidate_devices = selected_disks.map(&:name)
        end

      private

        def valid?
          any_selected_disk? && !many_selected_disks?
        end

        def any_selected_disk?
          return true unless selected_disks.empty?
          Yast::Report.Warning(_("At least one disk must be selected"))
          false
        end

        def many_selected_disks?
          return false if selected_disks.size <= MAX_DISKS
          Yast::Report.Warning(_("At most %d disks can be selected") % MAX_DISKS)
          true
        end

        def selected_disks
          all_disks.select { |d| widget_value(d.name) }
        end

        def all_disks
          analyzer.candidate_disks
        end
      end
    end
  end
end
