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

require "yast"
require "cwm"
require "y2storage"
require "tempfile"

module Y2Partitioner
  module Widgets
    # Widget to display a devicegraph
    #
    # It works only in graphical UI (i.e. the Graph widget is available) don't
    # use it in NCurses.
    class VisualDeviceGraph < CWM::CustomWidget
      # Configuration of the Graphviz export (information in the vertices)
      LABEL_FLAGS = Storage::GraphvizFlags_DISPLAYNAME

      # Configuration of the Graphviz export (tooltips)
      TOOLTIP_FLAGS = Storage::GraphvizFlags_PRETTY_CLASSNAME |
        Storage::GraphvizFlags_SIZE | Storage::GraphvizFlags_NAME

      private_constant :LABEL_FLAGS, :TOOLTIP_FLAGS

      # Constructor
      def initialize(device_graph, pager)
        textdomain "storage"

        @device_graph = device_graph
        @pager = pager
        @widget_id = "#{widget_id}_#{device_graph.object_id}"
      end

      # @macro seeCustomWidget
      def contents
        ReplacePoint(replace_point_id, Empty(graph_id))
      end

      # @macro seeAbstractWidget
      def init
        tmp = Tempfile.new("graph.gv")
        device_graph.write_graphviz(tmp.path, LABEL_FLAGS, TOOLTIP_FLAGS)
        content = ReplacePoint(
          replace_point_id,
          Yast::Term.new(:Graph, graph_id, Opt(:notify), tmp.path, "dot")
        )
        Yast::UI.ReplaceWidget(replace_point_id, content)
      ensure
        tmp.close!
      end

      # @macro seeAbstractWidget
      def handle
        node = Yast::UI.QueryWidget(graph_id, :Item)
        device = device_graph.find_device(node.to_i)
        return nil unless device

        page = find_target_page(device)
        return nil unless page

        pager.switch_page(page)
      end

      private

      # @return [Devicegraph] graph to display
      attr_reader :device_graph

      # @return [CWM::TreePager] main pager used to jump to the different
      #   partitioner sections
      attr_reader :pager

      # Id used for the main widget which is replaced with updated content on
      # every render (see {#init})
      def replace_point_id
        Id(:"#{widget_id}_content")
      end

      # Id used for the Graph widget and its original empty placeholder
      def graph_id
        Id(:"#{widget_id}_graph")
      end

      # Find the closest partitioner page for the given device
      #
      # If there is a page for that device, it returns that page. Otherwise, it
      # returns the page of the closest ancestor having such page.
      #
      # @return [CWM::Page, nil] nil if no appropiate page was found
      def find_target_page(device)
        page = pager.device_page(device)
        return page if page

        parents = device.parents
        return nil if parents.empty?

        find_ancestor_page(device)
      end

      # @see #find_target_page
      #
      # @return [CWM::Page, nil] nil if no appropiate page was found
      def find_ancestor_page(device)
        page = nil
        device.parents.each do |parent|
          page = find_target_page(parent)
          break if page
        end

        page
      end
    end
  end
end
