# Copyright (c) [2018] SUSE LLC
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

require "y2partitioner/icons"
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/device_graph_with_buttons"

module Y2Partitioner
  module Widgets
    module Pages
      # A page for displaying the device graphs (both current and system) in
      # interfaces supporting the Graph widget (Qt). Don't use in NCurses.
      class DeviceGraph < CWM::Page
        include Yast::I18n

        # Constructor
        #
        # @param pager [CWM::TreePager]
        def initialize(pager)
          textdomain "storage"

          @pager = pager
        end

        # @macro seeAbstractWidget
        def label
          _("Device Graphs")
        end

        def help
          tab_help(current_tab_label, current_tab_description) +
            tab_help(system_tab_label, system_tab_description)
        end

        # @macro seeCustomWidget
        def contents
          return @contents if @contents

          @tabs = Tabs.new(current_tab, system_tab)
          @contents = VBox(
            Left(
              HBox(
                Image(Icons::GRAPH, ""),
                # TRANSLATORS: Heading for the expert partitioner page
                Heading(_("Device Graphs"))
              )
            ),
            @tabs
          )
        end

        # @macro seeAbstractWidget
        def init
          # Start always in the first tab
          @tabs.switch_page(@tabs.initial_page)
        end

        private

        # @return [CWM::TreePager]
        attr_reader :pager

        # Tab displaying the current devicegraph with a brief explanation
        def current_tab
          DeviceGraphTab.new(
            current_tab_label,
            DeviceGraphs.instance.current,
            current_tab_description,
            pager
          )
        end

        def current_tab_label
          # TRANSLATORS: label for a tab
          _("Planned Devices")
        end

        def current_tab_description
          # TRANSLATORS: keep lines relatively short. Use \n if needed
          _("Final result that will be committed to the system.\n" \
            "This graph is updated on every user action.")
        end

        # Tab displaying the system devicegraph with a brief explanation
        def system_tab
          DeviceGraphTab.new(
            system_tab_label,
            DeviceGraphs.instance.system,
            system_tab_description,
            pager
          )
        end

        def system_tab_label
          # TRANSLATORS: label for a tab
          _("Current System Devices")
        end

        def system_tab_description
          # TRANSLATORS: keep lines relatively short. Use \n if needed
          _("Layout of the current system, before any of the scheduled changes.\n" \
            "This graph is created at startup. Updated if devices are rescanned.")
        end

        # Help text for a tab
        # @param tab_label [String]
        # @param tab_description [String]
        #
        def tab_help(tab_label, tab_description)
          "<p><b>" + tab_label + ":</b> " + tab_description + "</p>"
        end
      end

      # Class to represent every tab in the Device Graph page
      class DeviceGraphTab < CWM::Tab
        # @return [String]
        attr_reader :label

        # Constructor
        def initialize(label, device_graph, description, pager)
          @label = label
          @device_graph = device_graph
          @widget_id = "#{widget_id}_#{device_graph.object_id}"
          @description = description
          @pager = pager
        end

        # @macro seeCustomWidget
        def contents
          return @contents if @contents

          @contents = VBox(
            Left(Label(description)),
            DeviceGraphWithButtons.new(device_graph, pager)
          )
        end

        private

        # @return [String] explanation to display above the graph
        attr_reader :description

        # @return [Devicegraph] graph to display
        attr_reader :device_graph

        # @return [CWM::TreePager] main pager used to jump to the different
        #   partitioner sections
        attr_reader :pager
      end
    end
  end
end
