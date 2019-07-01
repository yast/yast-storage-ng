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
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "cwm"

module Y2Partitioner
  module Widgets
    # Like CWM::RadioButtons but each RB has a subordinate indented widget.
    # This is kind of like Pager, but all Pages being visible at once,
    # and enabled/disabled.
    # Besides {#items} you need to define also {#widgets}.
    class ControllerRadioButtons < CWM::CustomWidget
      def initialize
        self.handle_all_events = true
      end

      # @return [CWM::WidgetTerm]
      def contents
        Frame(
          label,
          HBox(
            HSpacing(hspacing),
            RadioButtonGroup(Id(widget_id), buttons_with_widgets),
            HSpacing(hspacing)
          )
        )
      end

      # @return [Numeric] margin at both sides of the options list
      def hspacing
        1.45
      end

      # @return [Numeric] margin above, between, and below the options
      def vspacing
        0.45
      end

      # @return [Array<Array(id,String)>]
      abstract_method :items

      # FIXME: allow {CWM::WidgetTerm}
      # @return [Array<AbstractWidget>]
      abstract_method :widgets

      # @param event [Hash] UI event
      def handle(event)
        eid = event["ID"]
        return nil unless ids.include?(eid)

        ids.zip(widgets).each do |id, widget|
          if id == eid
            widget.enable
          else
            widget.disable
          end
        end
        nil
      end

      # Get the currently selected radio button from the UI
      def value
        Yast::UI.QueryWidget(Id(widget_id), :CurrentButton)
      end

      # Tell the UI to change the currently selected radio button
      # @param val [Symbol, String] id of the widget corresponding
      #   to the currently selected option
      def value=(val)
        Yast::UI.ChangeWidget(Id(widget_id), :CurrentButton, val)
      end

      # @return [AbstractWidget] the widget corresponding
      #   to the currently selected option
      def current_widget
        idx = ids.index(value)
        widgets[idx]
      end

      private

      # @return [Array<id>]
      def ids
        @ids ||= items.map(&:first)
      end

      def buttons_with_widgets
        current_items = items
        current_widgets = widgets
        if current_items.size != current_widgets.size
          raise ArgumentError,
            "Length mismatch: items #{current_items.size}, widgets #{current_widgets.size}"
        end

        terms = current_items.zip(current_widgets).map do |(id, text), widget|
          VBox(
            VSpacing(vspacing),
            Left(RadioButton(Id(id), Opt(:notify), text)),
            Left(HBox(HSpacing(4), VBox(widget)))
          )
        end
        VBox(*terms, VSpacing(vspacing))
      end
    end
  end
end
