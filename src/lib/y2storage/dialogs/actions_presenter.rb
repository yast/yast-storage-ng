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

Yast.import "HTML"

module Y2Storage
  # Presenter for actions of an actiongraph
  class ActionsPresenter
    include Yast::I18n

    def initialize(actiongraph)
      @actiongraph = actiongraph
      @collapsed_subvolumes = true
    end

    # Changes the status of the presenter
    #
    # @param event [#to_s] event that change the status
    def update_status(event)
      toggle_subvolumes if event.to_s == toggle_subvolumes_event
    end

    # HTML representation for the actions of an actiongraph
    #
    # @return [Yast::Term]
    def to_html
      items = general_actions_items + subvolume_actions_items
      Yast::HTML.Para(html_list(items))
    end

    # List of events that the presenter can manage
    #
    # @return [Array<String>]
    def events
      [toggle_subvolumes_event]
    end

  protected

    attr_reader :actiongraph
    attr_reader :collapsed_subvolumes

    TOGGLE_SUBVOLUMES_EVENT = "actions_presenter--subvolumes"

    def toggle_subvolumes_event
      TOGGLE_SUBVOLUMES_EVENT
    end

    def toggle_subvolumes
      @collapsed_subvolumes = !@collapsed_subvolumes
    end

    def collapsed_subvolumes?
      @collapsed_subvolumes
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
  end
end
