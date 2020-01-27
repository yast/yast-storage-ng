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

require "y2partitioner/widgets/pages/bcaches"
require "y2partitioner/widgets/pages/btrfs_filesystems"
require "y2partitioner/widgets/pages/lvm"
require "y2partitioner/widgets/pages/md_raids"

module Y2Partitioner
  # Singleton class to keep the position of the user in the UI and other similar
  # information that needs to be remembered across UI redraws to give the user a
  # sense of continuity.
  class UIState
    # A collection holding the Node status for each CWM::Page visited by the user
    #
    # The CWM::Page#widget_id is used as index
    # @see #node_for
    #
    # @return [Hash{String => Node}]
    attr_reader :nodes

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
      @nodes = {}
      @current_node = nil
      @open_items = {}
      @overview_tree_pager = nil
    end

    # Method to be called when the user operates in a row of a table of devices
    # or creates a new device.
    #
    # @param device [Y2Storage::Device, Integer] sid or device object
    def select_row(device)
      sid = device.respond_to?(:sid) ? device.sid : device

      current_node&.selected_device = sid
    end

    # The sid of the associated device when a row must be selected in a table with devices
    #
    # @return [Integer, nil]
    def row_sid
      current_node&.selected_device
    end

    # Method to be called when the user decides to visit a given page by
    # clicking in one node of the general tree.
    #
    # It remembers the decision so the user is taken back to a sensible point of
    # the tree (very often the last he decided to visit) after redrawing.
    #
    # @param [CWM::Page] page associated to the tree node
    def go_to_tree_node(page)
      self.current_node = node_for(page)
    end

    # Method to be called when the user switches to a tab within a tree node.
    #
    # It remembers the decision so the same tab is showed when the same node will be redraw.
    #
    # @param [CWM::Page, String] page associated to the tab (or just its label)
    def switch_to_tab(page)
      current_node&.active_tab = page.respond_to?(:label) ? page.label : page
    end

    # Select the page to open in the general tree after a redraw
    #
    # @param pages [Array<CWM::Page>] all the pages in the tree
    # @return [CWM::Page, nil] the page to be opened; the initial one when nil
    def find_tree_node(pages)
      # candidate_nodes can be empty if the user has not left the overview page yet. So, do nothing
      return nil unless current_node

      current_node.candidate_nodes.each do |candidate|
        result = pages.find { |page| matches?(page, candidate) }
        return result if result
      end

      nil
    end

    # Select the tab to open within the node after a redraw
    #
    # @param pages [Array<CWM::Page>] pages for all the possible tabs
    # @return [CWM::Page, nil]
    def find_tab(pages)
      tab = current_node&.active_tab

      return nil unless tab

      pages.find { |page| page.label == tab }
    end

    # Method to be called when the user deletes a device to properly clear dead statuses
    #
    # Taking advantage of the path to the device provided by Node#candidate_nodes, it can discard
    # all no longer relevant statuses after deleting a device.
    #
    # @param sid [Integer] the sid of the deleted device
    def clear_statuses_for(sid)
      # All statuses containing the given sid as candidate must be discarded
      nodes.reject! { |_, v| v.candidate_nodes.include?(sid) }
    end

    # Stores the ids of the tree items that are open
    #
    # @note It has been decided to keep that logic here instead of moving it as part of each Node
    # status since it complicates things more than desired: UIState only tracks the status for each
    # visited item. Anyway, if it is being improved please bear in mind the default behavior to this
    # regard for items without children *yet*.
    def save_open_items
      return unless overview_tree_pager

      @open_items = overview_tree_pager.open_items
    end

    protected

    # A Node for the selected CWM::PageTreeItem
    #
    # @return [Node]
    attr_accessor :current_node

    # Returns the status representation for given page
    #
    # @param page [CWM::Page]
    # @return [Node] the current node status if it already exists; a new one when not.
    def node_for(page)
      nodes[page.widget_id] ||= Node.new(page)
    end

    # Whether the given page matches with the candidate tree node
    #
    # @param page [CWM::Page]
    # @param candidate [Integer, String]
    # @return boolean
    def matches?(page, candidate)
      if candidate.is_a?(Integer)
        page.respond_to?(:device) && page.device.sid == candidate
      else
        page.label == candidate
      end
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

    # Represent the UI status of a CWM::PagerTreeItem and its CWM::Page
    class Node
      # The key to reference the selected device for a table not wrapped in a tab
      FALLBACK_TAB = "root".freeze
      private_constant :FALLBACK_TAB

      # A reference to the active tab
      #
      # Useful to restore it when the user comes back after going to another node.
      #
      # @return [String]
      attr_accessor :active_tab

      # The path to the node, useful to correctly place the user within the tree after redrawing the
      # UI and also to remove useless statuses after deleting a device.
      #
      # @see UIState#find_tree_node
      # @see UIState#clear_status_for
      #
      # It could hold both, a device id (sid, Integer) or a page label (String).
      #
      # @return [Array<Integer, String>]
      attr_reader :candidate_nodes

      # Constructor
      #
      # @param page [CWM:Page] the related CWM::Page
      def initialize(page)
        @candidate_nodes = build_candidate_nodes(page)
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

      # Build the list of candidate nodes to go back after opening a device view in the tree
      #
      # @return [Array<Integer, String>]
      def build_candidate_nodes(page)
        if page.respond_to?(:device)
          device_page_candidates(page)
        else
          [page.label]
        end
      end

      # List of candidate nodes to go back after opening a device view in the tree
      #
      # @return [Array<Integer, String>]
      def device_page_candidates(page)
        device = page.device
        [device.sid, device_page_parent(device)].compact
      end

      # @see #device_page_candidates
      #
      # @return [Integer, String, nil] nil if there is no parent tree entry
      def device_page_parent(device)
        if device.is?(:partition)
          device.partitionable.sid
        elsif device.is?(:lvm_lv)
          device.lvm_vg.sid
        else
          device_page_section(device)
        end
      end

      # @see #device_page_candidates
      # @see #device_page_parent
      #
      # @return [Integer, String, nil] nil if there is no parent tree entry
      def device_page_section(device)
        if device.is?(:md)
          Widgets::Pages::MdRaids.label
        elsif device.is?(:lvm_vg)
          Widgets::Pages::Lvm.label
        elsif device.is?(:bcache)
          Widgets::Pages::Bcaches.label
        elsif device.is?(:btrfs)
          Widgets::Pages::BtrfsFilesystems.label
        end
      end

      # Returns the active tab or the fallback when none
      #
      # @return [String]
      def tab
        active_tab || FALLBACK_TAB
      end
    end
  end
end
