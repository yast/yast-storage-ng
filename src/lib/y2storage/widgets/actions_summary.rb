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

Yast.import "UI"
Yast.import "HTML"

module Y2Storage
  module Widgets
    # Widget to draw the actions of an actiongraph
    class ActionsSummary
      include Yast::UIShortcuts
      include Yast::I18n

      attr_reader :id

      def initialize(id, actiongraph)
        @id = id
        @actiongraph = actiongraph
        @collapsed_subvolumes = true
      end

      # Main handler for the widget. It can modify the widget content.
      #
      # @param input [#to_s] event to handle
      def handle(input)
        subvolumes_handler if input.to_s == toggle_subvolumes_event
      end

      # UI widget representation. It contains the list of actions.
      #
      # @return [Yast::Term]
      def content
        RichText(id, actions_summary)
      end

      # Name of the event to handle subvolumes toggling.
      #
      # @return [String]
      def toggle_subvolumes_event
        "#{id}--subvolumes"
      end

    protected

      attr_reader :actiongraph
      attr_reader :collapsed_subvolumes

      def subvolumes_handler
        toggle_subvolumes
        Yast::UI.ChangeWidget(id, :Value, actions_summary)
      end

      def actions_summary
        Yast::HTML.Para(actions_list)
      end

      def actions_list
        items = general_actions_items + subvolume_actions_items
        html_list(items)
      end

      def general_actions_items
        actions = sort_actions(general_actions)
        actions_to_items(actions)
      end

      def subvolume_actions_items
        actions = sort_actions(subvolume_actions)

        return [] if actions.empty?

        event = toggle_subvolumes_event
        if collapsed_subvolumes?
          # TRANSLATORS: %d is the amount of actions. Do not change href
          [_("%d subvolume actions (<a href=\"#{event}\">see details</a>)") % actions.size]
        else
          # TRANSLATORS: %d is the amount of actions. Do not change href
          header = _("%d subvolume actions (<a href=\"#{event}\">hide details</a>)") % actions.size
          list = html_list(actions_to_items(actions))
          [header, list]
        end
      end

      def general_actions
        return [] if actiongraph.nil?
        actiongraph.compound_actions.select { |a| !a.device_is?(:btrfs_subvolume) }
      end

      def subvolume_actions
        return [] if actiongraph.nil?
        actiongraph.compound_actions.select { |a| a.device_is?(:btrfs_subvolume) }
      end

      def sort_actions(actions)
        delete, other = actions.partition(&:delete?)
        delete.concat(other)
      end

      def actions_to_items(actions)
        actions.map { |a| action_to_item(a) }
      end

      def action_to_item(action)
        action.delete? ? Yast::HTML.Bold(action.sentence) : action.sentence
      end

      def html_list(items)
        Yast::HTML.List(items)
      end

      def collapsed_subvolumes?
        @collapsed_subvolumes
      end

      def toggle_subvolumes
        @collapsed_subvolumes = !@collapsed_subvolumes
      end
    end
  end
end
