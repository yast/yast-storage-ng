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

module Y2Partitioner
  module Widgets
    # A dummy page for prototyping
    # FIXME: remove it when no longer needed
    class GenericPage < CWM::Page
      attr_reader :label, :contents

      def initialize(id, label, contents)
        self.widget_id = id
        @label = label
        @contents = contents
      end
    end

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
        super(OverviewTree.new(items))
      end

      # @see http://www.rubydoc.info/github/yast/yast-yast2/CWM%2FTree:items
      def items
        [
          system_items,
          # TODO: only if there is graph support UI.HasSpecialWidget(:Graph)
          item_for("devicegraph", _("Device Graph"), icon: Icons::GRAPH),
          # TODO: only if there is graph support UI.HasSpecialWidget(:Graph)
          item_for("mountgraph", _("Mount Graph"), icon: Icons::GRAPH),
          item_for("summary", _("Installation Summary"), icon: Icons::SUMMARY),
          item_for("settings", _("Settings"), icon: Icons::SETTINGS)
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

      # Obtains the page associated to a specific device
      # @return [CWM::Page, nil]
      def device_page(device)
        @pages.find { |p| p.respond_to?(:device) && p.device.sid == device.sid }
      end

      # @macro seeAbstractWidget
      # Checks whether the current setup is valid, that is, it contains necessary
      # devices for booting (e.g., /boot/efi) and for the system runs properly (e.g., /).
      #
      # @see Y2Storage::SetupChecker
      #
      # @return [Boolean]
      def validate
        setup_checker = Y2Storage::SetupChecker.new(device_graph)
        return true if setup_checker.valid?

        errors = SetupErrorsPresenter.new(setup_checker).to_html
        # FIXME: improve Yast2::Popup to allow some text before the buttons
        errors += _("Do you want to continue?")

        result = Yast2::Popup.show(errors,
          headline: :error, richtext: true, buttons: :yes_no, focus: :no)

        result == :yes
      end

    private

      attr_reader :hostname

      def device_graph
        DeviceGraphs.instance.current
      end

      def system_items
        page = Pages::System.new(hostname, self)
        children = [
          disks_items,
          raids_items,
          lvm_items,
          crypt_files_items,
          device_mapper_items,
          nfs_items,
          btrfs_items,
          tmpfs_items,
          unused_items
        ]
        CWM::PagerTreeItem.new(page, children: children, icon: Icons::ALL)
      end

      def disks_items
        devices = device_graph.disk_devices
        page = Pages::Disks.new(devices, self)
        children = devices.map { |d| disk_items(d) }
        CWM::PagerTreeItem.new(page, children: children, icon: Icons::HD)
      end

      def disk_items(disk)
        page = Pages::Disk.new(disk, self)
        children = disk.partitions.sort_by(&:number).map { |p| partition_items(p) }
        CWM::PagerTreeItem.new(page, children: children)
      end

      def partition_items(partition)
        page = Pages::Partition.new(partition)
        CWM::PagerTreeItem.new(page)
      end

      def raids_items
        devices = device_graph.software_raids
        page = Pages::MdRaids.new(self)
        children = devices.map { |m| raid_items(m) }
        CWM::PagerTreeItem.new(page, children: children, icon: Icons::RAID)
      end

      def raid_items(md)
        page = Pages::MdRaid.new(md, self)
        CWM::PagerTreeItem.new(page)
      end

      def lvm_items
        devices = device_graph.lvm_vgs
        page = Pages::Lvm.new(self)
        children = devices.map { |v| lvm_vg_items(v) }
        CWM::PagerTreeItem.new(page, children: children, icon: Icons::LVM)
      end

      def lvm_vg_items(vg)
        page = Pages::LvmVg.new(vg, self)
        children = vg.all_lvm_lvs.sort_by(&:lv_name).map { |l| lvm_lv_items(l) }
        CWM::PagerTreeItem.new(page, children: children)
      end

      def lvm_lv_items(lv)
        page = Pages::LvmLv.new(lv)
        CWM::PagerTreeItem.new(page)
      end

      def crypt_files_items
        # TODO: real subtree
        item_for("loop", _("Crypt Files"), icon: Icons::LOOP, subtree: [])
      end

      def device_mapper_items
        # TODO: real subtree
        item_for("dm", _("Device Mapper"), icon: Icons::DM, subtree: [])
      end

      def nfs_items
        page = Pages::NfsMounts.new(self)
        CWM::PagerTreeItem.new(page, icon: Icons::NFS)
      end

      def btrfs_items
        page = Pages::Btrfs.new(self)
        CWM::PagerTreeItem.new(page, icon: Icons::BTRFS)
      end

      def tmpfs_items
        item_for("tmpfs", _("tmpfs"), icon: Icons::NFS)
      end

      def unused_items
        item_for("unused", _("Unused Devices"), icon: Icons::UNUSED)
      end

      def item_for(id, label, widget: nil, icon: nil, subtree: [])
        text = id.to_s.split(":", 2)[1] || id.to_s
        widget ||= Heading(text)
        contents = VBox(widget)
        page = GenericPage.new(id, label, contents)
        CWM::PagerTreeItem.new(page,
          icon: icon, open: open?(id), children: subtree)
      end

      def open?(id)
        id == "all"
      end
    end
  end
end
