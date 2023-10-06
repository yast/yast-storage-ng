# Copyright (c) [2017-2022] SUSE LLC
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
require "yast2/popup"
require "cwm/widget"
require "cwm/tree"
require "y2partitioner/icons"
require "y2partitioner/ui_state"
require "y2partitioner/widgets/pages"
require "y2storage/setup_errors_presenter"
require "y2storage/setup_checker"
require "y2storage/package_handler"
require "y2storage/bcache"

Yast.import "UI"
Yast.import "Mode"

module Y2Partitioner
  module Widgets
    # A tree that is told what its items are.
    # We need a tree whose items include Pages that point to the OverviewTreePager.
    class OverviewTree < CWM::Tree
      def initialize(items)
        super()
        textdomain "storage"
        @items = items
      end

      # @macro seeAbstractWidget
      def label
        ""
      end

      attr_reader :items
    end

    # Widget representing partitioner overview pager with tree on left side and rest on right side.
    #
    # It has replace point where it displays more details about selected element in partitioning.
    class OverviewTreePager < CWM::TreePager
      # Constructor
      #
      # @param [String] hostname of the system
      def initialize(hostname)
        textdomain "storage"

        @hostname = hostname
        super(OverviewTree.new(items))
      end

      # Ensures that UIState clears obsolete statuses and it is aware of current page
      #
      # That's especially needed when initial page is a candidate of a no longer existing one
      #
      # @see #initial_page
      def init
        super

        UIState.instance.prune(keep: @pages.map(&:id))
        UIState.instance.select_page(@current_page.tree_path)
      end

      # Ensures the tree is properly initialized according to {UIState} after
      # a redraw.
      #
      # @see #find_initial_page
      def initial_page
        find_initial_page || super
      end

      # @see http://www.rubydoc.info/github/yast/yast-yast2/CWM%2FTree:items
      def items
        [
          system_section,
          disks_section,
          raids_section,
          lvm_section,
          bcache_section,
          # TODO: Bring this back to life - disabled for now (bsc#1078849)
          # crypt_files_items,
          # device_mapper_items,
          btrfs_section,
          tmpfs_section,
          # TODO: Bring this back to life - disabled for now (bsc#1078849)
          # unused_items
          nfs_section
        ].compact
      end

      # Overrides default behavior of TreePager to register with {UIState} the status
      # of the current page and the new destination, before jumping to the tree node
      def switch_page(page)
        state = UIState.instance
        state.save_extra_info
        state.select_page(page.tree_path)
        super
      end

      # Status of open/expanded items in the UI
      #
      # @see UIState#open_items
      #
      # @return [Hash{String => Boolean}]
      def open_items
        items_with_children = with_children(tree.items)
        open_items = Yast::UI.QueryWidget(Id(tree.widget_id), :OpenItems).keys

        items_with_children.map { |i| [i.to_s, open_items.include?(i)] }.to_h
      end

      # Checks whether the current page is associated to a specific device
      #
      # @return [Boolean]
      def device_page?
        current_page.respond_to?(:device)
      end

      # Obtains the page associated to a specific device
      #
      # @param device [Y2Storage::Device]
      # @return [CWM::Page, nil]
      def device_page(device)
        @pages.find { |p| p.respond_to?(:device) && p.device.sid == device.sid }
      end

      # @macro seeAbstractWidget
      #
      # @return [Boolean]
      def validate
        valid_setup? && packages_installed?
      end

      # @macro seeAbstractWidget
      # @return [String] localized help text
      def help
        _(
          # TRANSLATORS: html text of the Partitioner Help. Please make sure the menu
          # names actually match the ones in the menubar widget
          "<p>Below the menu bar, the main element of the interface is the table\n" \
          "that represents the available devices, with some buttons to provide quick\n" \
          "access to the most common actions. Additionally, the <b>Add</b> and \n" \
          "<b>Device</b> menus can be used to perform any action on the device\n" \
          "selected in the table.</p>\n" \
          "<p>The left tree can be used to navigate through the list of devices,\n" \
          "focusing on a particular device or type of devices.</p>"
        )
      end

      private

      attr_reader :tree

      # Select the initial page
      #
      # @return [Page, nil]
      def find_initial_page
        candidate = UIState.instance.find_page(@pages.map(&:id))

        return nil unless candidate

        @pages.find { |page| page.id == candidate }
      end

      # Checks whether the current setup is valid, that is, it contains necessary
      # devices for booting (e.g., /boot/efi) and for the system runs properly (e.g., /).
      #
      # @see Y2Storage::SetupChecker
      #
      # @return [Boolean]
      def valid_setup?
        setup_checker = Y2Storage::SetupChecker.new(device_graph)
        return true if setup_checker.valid?

        errors = Y2Storage::SetupErrorsPresenter.new(setup_checker).to_html

        if setup_checker.errors.empty? # so only warnings there
          # FIXME: improve Yast2::Popup to allow some text before the buttons
          errors += _("Do you want to continue?")

          result = Yast2::Popup.show(errors,
            headline: :warning, richtext: true, buttons: :yes_no, focus: :no)

          result == :yes
        else
          Yast2::Popup.show(errors,
            headline: :error, richtext: true, buttons: :ok)
          false
        end
      end

      # Checks whether the needed packages are installed
      #
      # As a side effect, it will ask the user to install missing packages.
      #
      # @see Y2Storage::StorageFeature
      #
      # @return [Boolean]
      def packages_installed?
        return true if Yast::Mode.installation

        pkgs = device_graph.actiongraph.used_features.pkg_list
        Y2Storage::PackageHandler.new(pkgs).install
      end

      # @return [String]
      attr_reader :hostname

      def device_graph
        DeviceGraphs.instance.current
      end

      # @return [CWM::PagerTreeItem]
      def system_section
        page = Pages::System.new(hostname, self)

        section_item(page, Icons::ALL)
      end

      # @return [CWM::PagerTreeItem]
      def disks_section
        devices = device_graph.disk_devices + device_graph.stray_blk_devices

        page = Pages::Disks.new(devices, self)
        children = devices.map do |dev|
          dev.is?(:stray_blk_device) ? stray_blk_device_item(dev) : disk_items(dev)
        end
        section_item(page, Icons::HD, children: children)
      end

      # @return [CWM::PagerTreeItem]
      def disk_items(disk, page_class = Pages::Disk)
        page = page_class.new(disk, self)
        device_item(page)
      end

      # @return [CWM::PagerTreeItem]
      def stray_blk_device_item(device)
        page = Pages::StrayBlkDevice.new(device, self)
        device_item(page)
      end

      # @return [CWM::PagerTreeItem]
      def raids_section
        devices = device_graph.software_raids
        page = Pages::MdRaids.new(self)
        children = devices.map { |m| raid_items(m) }
        section_item(page, Icons::RAID, children: children)
      end

      # @return [CWM::PagerTreeItem]
      def raid_items(md)
        page = Pages::MdRaid.new(md, self)
        device_item(page)
      end

      # @return [CWM::PagerTreeItem]
      def bcache_section
        return nil unless Y2Storage::Bcache.supported?

        devices = device_graph.bcaches
        page = Pages::Bcaches.new(self)
        children = devices.map { |v| disk_items(v, Pages::Bcache) }
        section_item(page, Icons::BCACHE, children: children)
      end

      # @return [CWM::PagerTreeItem]
      def lvm_section
        devices = device_graph.lvm_vgs
        page = Pages::Lvm.new(self)
        children = devices.map { |v| lvm_vg_items(v) }
        section_item(page, Icons::LVM, children: children)
      end

      # @return [CWM::PagerTreeItem]
      def lvm_vg_items(vg)
        page = Pages::LvmVg.new(vg, self)
        device_item(page)
      end

      # @return [CWM::PagerTreeItem]
      def btrfs_section
        filesystems = device_graph.btrfs_filesystems.sort_by(&:blk_device_basename)

        page = Pages::BtrfsFilesystems.new(filesystems, self)
        children = filesystems.map { |f| btrfs_item(f) }

        section_item(page, Icons::BTRFS, children: children)
      end

      # @return [CWM::PagerTreeItem]
      def btrfs_item(filesystem)
        page = Pages::Btrfs.new(filesystem, self)
        device_item(page)
      end

      # @return [CWM::PagerTreeItem]
      def tmpfs_section
        page = Pages::TmpfsFilesystems.new(self)
        children = device_graph.tmp_filesystems.map { |f| tmpfs_item(f) }
        section_item(page, Icons::TMPFS, children: children)
      end

      # @param filesystem [Y2Storage::Filesystems::Tmpfs]
      # @return [CWM::PagerTreeItem]
      def tmpfs_item(filesystem)
        page = Pages::Tmpfs.new(filesystem, self)
        device_item(page)
      end

      # @return [CWM::PagerTreeItem]
      def nfs_section
        page = Pages::NfsMounts.new(self)
        children = device_graph.nfs_mounts.map { |f| nfs_item(f) }
        section_item(page, Icons::NFS, children: children)
      end

      # @param nfs [Y2Storage::Filesystems::Nfs]
      # @return [CWM::PagerTreeItem]
      def nfs_item(nfs)
        page = Pages::Nfs.new(nfs, self)
        device_item(page)
      end

      # Generates a `section` tree item for given page
      #
      # The OverviewTreePager has two kinds of items: section or device. Sections always has icon
      # and starts expanded; devices has not icon and starts collapsed. See also {device_item}.
      #
      # @param page [CWM::Page]
      # @param icon [Icons]
      # @param children [Array<CWM::PagerTreeItem>]
      #
      # @return [CWM::PagerTreeItem]
      def section_item(page, icon, children: [])
        CWM::PagerTreeItem.new(page, children: children, icon: icon, open: item_open?(page, true))
      end

      # Generates a `device` tree item for given page
      #
      # @see #section_item
      #
      # @param page [CWM::Page]
      # @param children [Array<CWM::PagerTreeItem>]
      #
      # @return [CWM::PagerTreeItem]
      def device_item(page, children: [])
        CWM::PagerTreeItem.new(page, children: children, open: item_open?(page, false))
      end

      # For a list of tree entries, returns the ids of those that have children,
      # including nested tree entries (i.e. recursively)
      #
      # @param items [Array<CWM::PagerTreeItem>]
      # @return [Array<String, Symbol>]
      def with_children(items)
        items = items.select { |i| i.children.any? }
        items.map(&:id) + items.flat_map { |i| with_children(i.children.values) }
      end

      # Whether the tree item for given page should be open (expanded) or closed (collapsed)
      #
      # When open items are not initialized, the default value will be used. For better
      # understanding, see the note about the {OverviewTreePager} redrawing in
      # {Dialogs::Main#contents}
      #
      # @param page [CWM::Page]
      # @param default [Boolean] value when open items are not initialized yet
      #
      # @return [Boolean] true when item must be expanded; false if must be collapsed
      def item_open?(page, default)
        UIState.instance.open_items.fetch(page.widget_id.to_s, default)
      end
    end
  end
end
