# encoding: utf-8

# Copyright (c) [2017-2019] SUSE LLC
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
require "y2partitioner/device_graphs"
require "y2partitioner/ui_state"
require "y2partitioner/widgets/pages"
require "y2partitioner/setup_errors_presenter"
require "y2storage/setup_checker"
require "y2storage/used_storage_features"
require "y2storage/bcache"

Yast.import "UI"
Yast.import "PackageSystem"
Yast.import "Mode"

module Y2Partitioner
  module Widgets
    # A tree that is told what its items are.
    # We need a tree whose items include Pages that point to the OverviewTreePager.
    class OverviewTree < CWM::Tree
      def initialize(items)
        textdomain "storage"
        @items = items
      end

      # @macro seeAbstractWidget
      def label
        _("System View")
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
        @invalidated_pages = []
        super(OverviewTree.new(items))
      end

      # Pages whose cached content should be considered outdated
      #
      # This is a hack introduced because the NFS page works in a completely
      # different way in which triggering a full redraw every time something
      # changes is not an option. This way, the NFS page can invalidate the
      # cached contents of other pages supporting this mechanism.
      #
      # @return [Array<Symbol>] only :system supported so far
      attr_accessor :invalidated_pages

      # @see http://www.rubydoc.info/github/yast/yast-yast2/CWM%2FTree:items
      def items
        [
          system_items,
          *graph_items,
          summary_item,
          settings_item
        ]
      end

      # Overrides default behavior of TreePager to register the new state with
      # {UIState} before jumping to the tree node
      def switch_page(page)
        UIState.instance.go_to_tree_node(page)
        super
      end

      # Ensures the tree is properly initialized according to {UIState} after
      # a redraw.
      def initial_page
        UIState.instance.find_tree_node(@pages) || super
      end

      # Status of open/expanded items in the UI
      #
      # @see UIState#open_items
      #
      # @return [Hash{String => Boolean}]
      def open_items
        items_with_children = with_children(tree.items)
        open_items = Yast::UI.QueryWidget(Id(tree.widget_id), :OpenItems).keys

        Hash[items_with_children.map { |i| [i.to_s, open_items.include?(i)] }]
      end

      # Obtains the page associated to a specific device
      # @return [CWM::Page, nil]
      def device_page(device)
        if device.is?(:nfs)
          # NFS is a special case because NFS devices don't have individual
          # pages, all NFS devices are managed directly in the NFS list
          @pages.find { |p| p.is_a?(Pages::NfsMounts) }
        else
          @pages.find { |p| p.respond_to?(:device) && p.device.sid == device.sid }
        end
      end

      # @macro seeAbstractWidget
      #
      # @return [Boolean]
      def validate
        valid_setup? && packages_installed?
      end

    private

      attr_reader :tree

      # Checks whether the current setup is valid, that is, it contains necessary
      # devices for booting (e.g., /boot/efi) and for the system runs properly (e.g., /).
      #
      # @see Y2Storage::SetupChecker
      #
      # @return [Boolean]
      def valid_setup?
        setup_checker = Y2Storage::SetupChecker.new(device_graph)
        return true if setup_checker.valid?

        errors = SetupErrorsPresenter.new(setup_checker).to_html

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
      # @see Y2Storage::UsedStorageFeatures
      #
      # @return [Boolean]
      def packages_installed?
        return true if Yast::Mode.installation
        used_features = Y2Storage::UsedStorageFeatures.new(device_graph)
        used_features.collect_features
        Yast::PackageSystem.CheckAndInstallPackages(used_features.feature_packages)
      end

      # @return [String]
      attr_reader :hostname

      def device_graph
        DeviceGraphs.instance.current
      end

      # @return [CWM::PagerTreeItem]
      def system_items
        page = Pages::System.new(hostname, self)
        children = [
          disks_section,
          raids_section,
          lvm_section,
          bcache_section,
          # TODO: Bring this back to life - disabled for now (bsc#1078849)
          # crypt_files_items,
          # device_mapper_items,
          nfs_section,
          btrfs_section
          # TODO: Bring this back to life - disabled for now (bsc#1078849)
          # unused_items
        ].compact

        section_item(page, Icons::ALL, children: children)
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
        children = disk.partitions.sort_by(&:number).map { |p| partition_items(p) }
        device_item(page, children: children)
      end

      # @return [CWM::PagerTreeItem]
      def partition_items(partition)
        page = Pages::Partition.new(partition)
        device_item(page)
      end

      # @return [CWM::PagerTreeItem]
      def stray_blk_device_item(device)
        page = Pages::StrayBlkDevice.new(device)
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
        children = md.partitions.sort_by(&:number).map { |p| partition_items(p) }
        device_item(page, children: children)
      end

      # @return [CWM::PagerTreeItem]
      def bcache_section
        return nil unless Y2Storage::Bcache.supported?
        devices = device_graph.bcaches
        page = Pages::Bcaches.new(devices, self)
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
        children = vg.all_lvm_lvs.sort_by(&:lv_name).map { |l| lvm_lv_items(l) }
        device_item(page, children: children)
      end

      # @return [CWM::PagerTreeItem]
      def lvm_lv_items(lv)
        page = Pages::LvmLv.new(lv)
        device_item(page)
      end

      # @return [CWM::PagerTreeItem]
      def nfs_section
        page = Pages::NfsMounts.new(self)
        section_item(page, Icons::NFS)
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

      # @return [Array<CWM::PagerTreeItem>]
      def graph_items
        return [] unless Yast::UI.HasSpecialWidget(:Graph)

        page = Pages::DeviceGraph.new(self)
        dev_item = section_item(page, Icons::GRAPH)
        # TODO: Bring this back to life - disabled for now (bsc#1078849)
        # mount_item = item_for("mountgraph", _("Mount Graph"), icon: Icons::GRAPH)
        # [dev_item, mount_item]
        [dev_item]
      end

      # @return [CWM::PagerTreeItem]
      def summary_item
        page = Pages::Summary.new
        section_item(page, Icons::SUMMARY)
      end

      # @return [CWM::PagerTreeItem]
      def settings_item
        page = Pages::Settings.new
        section_item(page, Icons::SETTINGS)
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
