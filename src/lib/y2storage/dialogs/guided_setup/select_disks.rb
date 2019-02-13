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
        def initialize(*params)
          textdomain "storage"
          super
        end

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

        # Maximum number of disks the user is allowed to select
        MAX_DISKS = 3

        # Maximum number of disks that can be displayed at the same time with
        # the default interface. If that number is exceeded an alternative
        # interface with scroll is displayed.
        DISKS_WITHOUT_SCROLL = 10

        def dialog_title
          _("Select Hard Disk(s)")
        end

        def dialog_content
          items = all_disks.map { |d| [d.name, disk_label(d)] }
          label = _("Select one or more (max %d) hard disks") % MAX_DISKS
          disks_widget.content(label, items)
        end

        def initialize_widgets
          default_selected = settings.candidate_devices || []
          default_selected = default_selected.map { |d| analyzer.device_by_name(d) }
          default_selected = all_disks if default_selected.empty?
          disks_widget.select(default_selected.first(MAX_DISKS).map(&:name))
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
          all_disks.select { |d| disks_widget.selected?(d.name) }
        end

        def all_disks
          analyzer.candidate_disks
        end

        # Widget used to display and select the list of disks
        #
        # @return [DisksWidget, ScrollableDisksWidget]
        def disks_widget
          @disks_widget ||=
            if all_disks.size > DISKS_WITHOUT_SCROLL
              ScrollableDisksWidget.new
            else
              DisksWidget.new
            end
        end

        # Auxiliary internal class to draw and query the list of disks in the
        # default case
        class DisksWidget
          include Yast::UIShortcuts

          # @see SelectDisks#content
          #
          # @param label [String] heading of the widget
          # @param items [Array<Array<String>>] list of pairs (id, description)
          def content(label, items)
            HSquash(
              VBox(
                Left(Label(label)),
                VSpacing(0.3),
                *items.map { |item| disk_widget(item) }
              )
            )
          end

          # @see SelectDisks#initialize_widgets
          def select(ids)
            ids.each { |id| Yast::UI.ChangeWidget(Id(id), :Value, true) }
          end

          # @see SelectDisks#selected_disks
          def selected?(id)
            Yast::UI.QueryWidget(Id(id), :Value)
          end

        protected

          # @see #content
          def disk_widget(item)
            Left(CheckBox(Id(item.first), item.last))
          end
        end

        # Auxiliary internal class to draw and query the list of disks when
        # there are so many disks that the default widget cannot deal with it
        class ScrollableDisksWidget
          include Yast::UIShortcuts

          # @see SelectDisks#content
          #
          # @param label [String] heading of the widget
          # @param items [Array<Array<String>>] list of pairs (id, description)
          def content(label, items)
            MarginBox(
              2, 1,
              MultiSelectionBox(
                Id(:disks),
                label,
                items.map { |item| Item(Id(item.first), item.last) }
              )
            )
          end

          # @see SelectDisks#initialize_widgets
          def select(ids)
            Yast::UI.ChangeWidget(Id(:disks), :SelectedItems, ids)
          end

          # @see SelectDisks#selected_disks
          def selected?(id)
            Yast::UI.QueryWidget(Id(:disks), :SelectedItems).include?(id)
          end
        end
      end
    end
  end
end
