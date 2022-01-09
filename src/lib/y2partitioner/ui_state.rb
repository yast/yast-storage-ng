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

module Y2Partitioner
  # Singleton class to keep the position of the user in the UI and other similar
  # information that needs to be remembered across UI redraws to give the user a
  # sense of continuity.
  class UIState
    # A collection holding a PageStatus for each Page visited by the user
    #
    # @return [Array<PageStatus>]
    attr_reader :statuses

    # A reference to the overview tree pager, which is a new instance every dialog redraw. See note
    # in {Dialogs::Main#contents}
    #
    # @return [Widgets::OverviewTreePager]
    attr_accessor :overview_tree_pager

    # A reference to the main menu bar, which is a new instance on every dialog redraw
    #
    # @return [Widgets::MainMenuBar]
    attr_accessor :menu_bar

    # Hash listing all the items with children of the tree and specifying whether
    # such item should be expanded (true) or collapsed (false) in the next redraw.
    #
    # @note Only elements with children are stored, for the others the current state
    # is not relevant (not having children, they are neither open or closed).
    #
    # @return [Hash{String => Boolean}]
    attr_reader :open_items

    # Constructor
    #
    # Called through {.create_instance}, starts with a blank situation (which
    # means default for each widget will be honored).
    def initialize
      @statuses = []
      @current_status = nil
      @open_items = {}
      @overview_tree_pager = nil
    end

    # Method to be called when the user operates in a row of a table of devices
    # or creates a new device.
    #
    # @param row_id [Integer] the id of selected row
    def select_row(row_id)
      current_status&.selected_row = row_id
      menu_bar&.select_row(row_id)
    end

    # Method to be called when the user decides to visit a page by clicking in one node of the
    # general tree.
    #
    # It remembers the decision so the user is taken back to a sensible point of
    # the tree (very often the last he decided to visit) after redrawing.
    #
    # @param pages_ids [Array<String, Integer>] the path to the selected page
    def select_page(pages_ids)
      self.current_status = status_for(pages_ids)
      menu_bar&.select_page
    end

    # Method to be called when the user switches to a tab within a page
    #
    # It records the decision, so the last active tab is displayed when the page will be redraw.
    #
    # If the selected tab is the default one of the page, nil must be passed as argument
    #
    # @param label [String, nil] nil if switching to the default tab, no matter the label
    def switch_to_tab(label)
      current_status&.active_tab = label
    end

    # Additional state information for the active tab of the current page
    #
    # FIXME: in the mid-term, it would be nice to turn this into a proper API to
    # store and fetch the status of each individual widget within the page, instead
    # of this generic container for the state of the full tab/page.
    #
    # @return [Object, nil]
    def extra
      current_status&.extra
    end

    # Sets the additional state information for the active page and tab
    #
    # @param info [Object, nil]
    def extra=(info)
      current_status.extra = info
    end

    # Stores the information of the active tab of the current page
    #
    # @see #extra
    # @see #extra=
    #
    # FIXME: see the comment in #extra. At some point, the #state_info method
    # should be moved to each widget needing to store its information and the
    # page itself would offer a method to make possible to iterate through all
    # those widgets (e.g. #widgets_with_state_info).
    def save_extra_info
      page = overview_tree_pager&.current_page
      return unless page.respond_to?(:state_info)

      self.extra = page.state_info
    end

    # Returns the id of the last selected row in the active tab of current page
    #
    # @return [Integer, nil]
    def row_id
      current_status&.selected_row
    end

    # Select the page to open in the general tree after a redraw
    #
    # @param pages_ids [Array<String, Integer>] all pages ids in the tree
    # @return [String, Integer, nil] the page id to be opened or nil
    def find_page(pages_ids)
      return nil unless current_status

      # Let's pick the more accurate, which means that it is present in both the tree and the
      # candidates. See PageStatus#candidate_pages.
      (current_status.candidate_pages & pages_ids).last
    end

    # Select the last active tab fo current PageStatus
    #
    # @see PageStatus#active_tab
    #
    # @return [String, nil]
    def active_tab
      current_status&.active_tab
    end

    # Method to be called when redrawing the UI to keep tracking only valid statuses
    #
    # Usually, the UI is redrawn after certain user actions like deleting a device.
    #
    # @param keep [Array<String, Integer>] pages ids of statuses to keep
    def prune(keep: [])
      statuses.select! { |s| keep.include?(s.page_id) }
    end

    # Stores the ids of the tree items that are open
    #
    # @note It has been decided to keep that logic here instead of moving it as part of each
    # PageStatus because it complicates things more than desired.
    def save_open_items
      return unless overview_tree_pager

      @open_items = overview_tree_pager.open_items
    end

    protected

    # The current status
    #
    # @return [PageStatus]
    attr_reader :current_status

    # Sets the current status
    #
    # Note that the active tab is not stored when switching to the status of another page.
    #
    # @param status [PageStatus]
    def current_status=(status)
      current_status.active_tab = nil if current_status && current_status != status

      @current_status = status
    end

    # Returns the status representation for a page
    #
    # @param pages_ids [Array<String, Integer>] the path to the page. See PageStatus#candidate_pages
    # @return [PageStatus] the current status if it already exists; a new one when not.
    def status_for(pages_ids)
      id = pages_ids.last
      status = statuses.find { |s| s.page_id == id }

      return status unless status.nil?

      statuses << PageStatus.new(id, pages_ids)
      statuses.last
    end

    class << self
      # Singleton instance
      def instance
        create_instance unless @instance
        @instance
      end

      # Enforce a new clean instance
      def create_instance
        @instance = new
      end

      # Make sure only .instance and .create_instance can be used to
      # create objects
      private :new, :allocate
    end

    # Represents the UI status for a CWM::Page
    #
    # For the time being, it is able to keep
    #
    #   * current tab
    #   * selected row
    #   * candidates pages
    class PageStatus
      # The key to reference the default tab of a page or to use when the page contains
      # no known tabs
      FALLBACK_TAB = "root".freeze
      private_constant :FALLBACK_TAB

      # A reference to the active tab
      #
      # Useful to restore it when the user comes back after going to another node.
      #
      # @return [String]
      attr_accessor :active_tab

      # The Widgets::Pages::Base#id
      #
      # @return [String, Integer]
      attr_reader :page_id

      # A partial path to a page, useful to correctly place the user within the tree after
      # redrawing the UI and also to remove useless statuses after deleting a device.
      #
      # This path always contains the page parent id and the page id itself. So, taking a partition
      # as an example, it will be [disk_page_id, partition_page_id]
      #
      # @see UIState#find_page
      # @see UIState#clear_statuses_for
      #
      # It stores page ids, see Pages::Base#id
      #
      # @return [Array<String, Integer>]
      attr_reader :candidate_pages

      # Constructor
      #
      # @param page_id [String, Integer] the Widgets::Pages::Base#id identifying the page
      # @param candidate_pages_ids [Array<String, Integer>] a list of Widgets::Pages::Base#id
      def initialize(page_id, candidate_pages_ids)
        @page_id = page_id
        @candidate_pages = candidate_pages_ids
        @selected_rows = { FALLBACK_TAB => nil }
        @extras = {}
      end

      # Returns the last selected row for the active tab
      #
      # If the node has no tabs a fallback reference will be used. See #selected_rows
      #
      # @return [Integer, nil]
      def selected_row
        selected_rows[tab]
      end

      # Stores selected row for the active tab
      #
      # If the node has no tabs a fallback reference will be used. See #selected_rows
      #
      # @param sid [Integer] the device sid
      def selected_row=(sid)
        selected_rows[tab] = sid
      end

      # Returns the extra information previously stored for the active tab
      #
      # If the node has no tabs a fallback reference will be used. See #selected_rows
      #
      # @return [Object, nil]
      def extra
        extras[tab]
      end

      # Stores the extra information for the active tab
      #
      # If the node has no tabs a fallback reference will be used. See #selected_rows
      #
      # @param info [Object, nil]
      def extra=(info)
        extras[tab] = info
      end

      private

      # A collection to keep the selected rows per tab
      #
      # The FALLBACK_TAB key will be used to reference the selected row of a CWM::Page with a
      # table not wrapped within a tab (e.g, Widgets::Pages::System, Widgets:Pages::Disks,
      # etc)
      #
      # @return [Hash{String => Integer}]
      attr_reader :selected_rows

      # A collection to keep the additional information for each page and tab
      #
      # As in {#selected_rows}, FALLBACK_TAB is used as key in some cases.
      #
      # @return [Hash{String => Object}]
      attr_reader :extras

      # Returns the active tab or the fallback when none
      #
      # @return [String]
      def tab
        active_tab || FALLBACK_TAB
      end
    end
  end
end
