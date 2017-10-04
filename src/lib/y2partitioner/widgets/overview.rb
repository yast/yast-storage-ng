require "cwm/widget"
require "cwm/tree"
require "y2partitioner/icons"
require "y2partitioner/device_graphs"
require "y2partitioner/ui_state"
require "y2partitioner/widgets/system_page"
require "y2partitioner/widgets/disks_page"
require "y2partitioner/widgets/disk_page"
require "y2partitioner/widgets/partition_page"
require "y2partitioner/widgets/md_raids_page"
require "y2partitioner/widgets/md_raid_page"
require "y2partitioner/widgets/lvm_page"
require "y2partitioner/widgets/lvm_vg_page"
require "y2partitioner/widgets/lvm_lv_page"
require "y2partitioner/widgets/btrfs_page"

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
      def initialize
        textdomain "storage"

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

    private

      def device_graph
        DeviceGraphs.instance.current
      end

      def system_items
        page = SystemPage.new(self)
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
        page = DisksPage.new(self)
        children = device_graph.disks.map { |d| disk_items(d) }
        CWM::PagerTreeItem.new(page, children: children, icon: Icons::HD)
      end

      def disk_items(disk)
        page = DiskPage.new(disk, self)
        children = disk.partitions.map { |p| partition_items(p) }
        CWM::PagerTreeItem.new(page, children: children)
      end

      def partition_items(partition)
        page = PartitionPage.new(partition)
        CWM::PagerTreeItem.new(page)
      end

      def raids_items
        page = MdRaidsPage.new(self)
        children = Y2Storage::Md.all(device_graph).map { |m| raid_items(m) }
        CWM::PagerTreeItem.new(page, children: children, icon: Icons::RAID)
      end

      def raid_items(md)
        page = MdRaidPage.new(md, self)
        CWM::PagerTreeItem.new(page)
      end

      def lvm_items
        page = LvmPage.new(self)
        children = device_graph.lvm_vgs.map { |v| lvm_vg_items(v) }
        CWM::PagerTreeItem.new(page, children: children, icon: Icons::LVM)
      end

      def lvm_vg_items(vg)
        page = LvmVgPage.new(vg, self)
        children = vg.lvm_lvs.map { |l| lvm_lv_items(l) }
        CWM::PagerTreeItem.new(page, children: children)
      end

      def lvm_lv_items(lv)
        page = LvmLvPage.new(lv)
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
        item_for("nfs", _("NFS"), icon: Icons::NFS)
      end

      def btrfs_items
        page = BtrfsPage.new(self)
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
