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
    # @param device [Y2Storage::Device, Integer] a device or its sid
    def select_row(device)
      sid = device.respond_to?(:sid) ? device.sid : device

      current_status&.selected_device = sid
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
    end

    # Method to be called when the user switches to a tab within a page
    #
    # It records the decision, so the last active tab is displayed when the page will be redraw.
    #
    # @param label [String]
    def switch_to_tab(label)
      current_status&.active_tab = label
    end

    # Returns the sid of the last selected device in the active tab of current page
    #
    # @return [Integer, nil]
    def row_sid
      current_status&.selected_device
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

    # Method to be called when the user deletes a device to properly clear dead statuses
    #
    # Taking advantage of the path to the device provided by PageStatus#candidate_pages, it can
    # discard all no longer relevant statuses after deleting a device.
    #
    # @param sid [Integer] the sid of the deleted device
    def clear_statuses_for(sid)
      # All statuses containing the given sid as candidate must be discarded
      statuses.reject! { |v| v.candidate_pages.include?(sid) }
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
    attr_accessor :current_status

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
      # The key to reference the selected device for a table not wrapped in a tab
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
        @selected_devices = { FALLBACK_TAB => nil }
      end

      # Returns the last selected device for the active tab
      #
      # If the node has no tabs a fallback reference will be used. See #selected_devices
      #
      # @return [Integer, nil]
      def selected_device
        selected_devices[tab]
      end

      # Stores selected device for the active tab
      #
      # If the node has no tabs a fallback reference will be used. See #selected_devices
      #
      # @param sid [Integer] the device sid
      def selected_device=(sid)
        selected_devices[tab] = sid
      end

      private

      # A collection to keep the selected devices per tab
      #
      # The FALLBACK_TAB key will be used to reference the selected device of a CWM::Page with a
      # devices table not wrapped within a tab (e.g, Widgets::Pages::System, Widgets:Pages::Disks,
      # etc)
      #
      # @return [Hash{String => Integer}]
      attr_reader :selected_devices

      # Returns the active tab or the fallback when none
      #
      # @return [String]
      def tab
        active_tab || FALLBACK_TAB
      end
    end
  end
end
