# encoding: utf-8

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
require "y2partitioner/widgets/visual_device_graph"

Yast.import "UI"

module Y2Partitioner
  module Widgets
    # Widget to display a devicegraph and the corresponding buttons to export it
    #
    # It works only in graphical UI (i.e. the Graph widget is available) don't
    # use it in NCurses.
    class DeviceGraphWithButtons < CWM::CustomWidget
      # Constructor
      def initialize(device_graph, pager)
        textdomain "storage"

        @device_graph = device_graph
        @pager = pager
      end

      # @macro seeCustomWidget
      def contents
        VBox(
          VisualDeviceGraph.new(device_graph, pager),
          Left(
            HBox(
              SaveDeviceGraphButton.new(device_graph, :xml),
              SaveDeviceGraphButton.new(device_graph, :gv)
            )
          )
        )
      end

    private

      # @return [Devicegraph] graph to display
      attr_reader :device_graph

      # @return [CWM::TreePager] main pager used to jump to the different
      #   partitioner sections
      attr_reader :pager
    end

    # Widget for exporting a devicegraph in XML or Grapviz format
    class SaveDeviceGraphButton < CWM::PushButton
      # Configuration of the Graphviz export (information in the vertices)
      LABEL_FLAGS = Storage::GraphvizFlags_DISPLAYNAME

      # Configuration of the Graphviz export (tooltips)
      TOOLTIP_FLAGS = Storage::GraphvizFlags_PRETTY_CLASSNAME |
        Storage::GraphvizFlags_SIZE | Storage::GraphvizFlags_SID |
        Storage::GraphvizFlags_ACTIVE | Storage::GraphvizFlags_IN_ETC

      private_constant :LABEL_FLAGS, :TOOLTIP_FLAGS

      # Constructor
      def initialize(device_graph, format)
        textdomain "storage"

        @device_graph = device_graph
        @format = format
        @widget_id = "#{widget_id}_#{device_graph.object_id}_#{format}"
      end

      # @macro seeAbstractWidget
      def label
        if xml?
          _("Save as XML...")
        else
          _("Save as Graphviz...")
        end
      end

      # @macro seeAbstractWidget
      def handle
        filename = Yast::UI.AskForSaveFileName("/tmp/yast.#{format}", "*.#{format}", "Save as...")
        return if filename.nil?
        return if save(filename)

        # TRANSLATORS: Error pop-up message
        Yast::Popup.Error(_("Saving graph file failed."))
      end

    private

      # @return [Devicegraph] graph to display and export
      attr_reader :device_graph

      # @return [Symbol] :xml or :gv
      attr_reader :format

      # Whether this button exports to XML
      def xml?
        format == :xml
      end

      # Saves the device graph into the corresponding XML or Graphviz file
      #
      # @param filename [String]
      # @return [Boolean] true if the file was successfully written, false
      #   otherwise
      def save(filename)
        if xml?
          device_graph.save(filename)
        else
          device_graph.write_graphviz(filename, LABEL_FLAGS, TOOLTIP_FLAGS)
        end
        true
      rescue Storage::Exception
        false
      end
    end
  end
end
