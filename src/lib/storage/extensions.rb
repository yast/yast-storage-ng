# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

require "storage"
require "expert_partitioner/icons"
require "expert_partitioner/tree_views/disk"
require "expert_partitioner/tree_views/md"
require "expert_partitioner/tree_views/partition"
require "expert_partitioner/tree_views/lvm_vg"
require "expert_partitioner/tree_views/lvm_lv"
require "expert_partitioner/tree_views/luks"

include Yast::UIShortcuts

module Storage
  def self.silence
    silencer = ::Storage::Silencer.new
    yield
  ensure
    silencer.turn_off
  end

  class Device
    extend Yast::I18n
    textdomain "storage"

    # This code is only executed once (when the class is loaded), but YaST
    # allows to change the language in execution time. Thus, we use N_() here
    # to mark the code as translatable and _() in .table_header to perform the
    # real translation on execution time.
    FIELD_NAMES = {
      sid:             N_("Storage ID"),
      icon:            N_("Icon"),
      name:            N_("Name"),
      vg_name:         N_("VG Name"),
      lv_name:         N_("LV Name"),
      blk_device_name: N_("Block Device Name"),
      size:            N_("Size"),
      partition_table: N_("Partition Table"),
      filesystem:      N_("Filesystem"),
      mountpoint:      N_("Mount Point"),
      label:           N_("Label"),
      uuid:            N_("UUID"),
      transport:       N_("Transport"),
      mount_by:        N_("Mount By"),
      md_level:        N_("RAID Level"),
      spare:           N_("Spare"),
      faulty:          N_("Faulty"),
      stripe_info:     N_("Stripes")
    }
    private_constant :FIELD_NAMES

    def self.table_header(fields)
      names = fields.map do |field|
        name = _(FIELD_NAMES[field])
        field == :size ? Right(name) : name
      end
      return Header(*names)
    end

    def make_icon_cell(icon, text)
      return Yast::Term.new(
        :cell,
        Yast::Term.new(:icon, "#{Yast::Directory.icondir}/22x22/apps/#{icon}"),
        text
      )
    end

    def table_row(fields)
      Item(Id(sid), *fields.map { |field| send("table_#{field}") })
    end

    def table_sid
      return sid
    end

    def table_icon
      return make_icon_cell(ExpertPartitioner::Icons::DEVICE, "Device")
    end

    def table_name
      return ""
    end

    def table_size
      return ""
    end

    def table_partition_table
      return ""
    end

    def table_filesystem
      return ""
    end

    def table_mountpoint
      return ""
    end

    def table_label
      return ""
    end

    def table_uuid
      return ""
    end

    def table_transport
      return ""
    end

    def table_mount_by
      return ""
    end

    def table_md_level
      return ""
    end

    def table_spare
      return ""
    end

    def table_faulty
      return ""
    end
  end

  class BlkDevice
    def table_name
      return name
    end

    def table_size
      return ::Storage.byte_to_humanstring(size, false, 2, false)
    end

    def table_filesystem
      return filesystem.table_filesystem
    rescue ::Storage::WrongNumberOfChildren, ::Storage::DeviceHasWrongType
      return ""
    end

    def table_mountpoint
      return filesystem.table_mountpoint
    rescue ::Storage::WrongNumberOfChildren, ::Storage::DeviceHasWrongType
      return ""
    end

    def table_spare
      spare = out_holders.to_a.any? do |holder|
        ::Storage.md_user?(holder) && ::Storage.to_md_user(holder).spare?
      end
      spare ? "Spare" : ""
    end

    def table_faulty
      faulty = out_holders.to_a.any? do |holder|
        ::Storage.md_user?(holder) && ::Storage.to_md_user(holder).faulty?
      end
      faulty ? "Faulty" : ""
    end
  end

  class Partitionable
    def table_partition_table
      return ::Storage.pt_type_name(partition_table.type)
    rescue ::Storage::WrongNumberOfChildren, ::Storage::DeviceHasWrongType
      return ""
    end
  end

  class Disk
    def table_icon
      return make_icon_cell(ExpertPartitioner::Icons::DISK, "Disk")
    end

    def table_transport
      if transport != Transport_UNKNOWN
        return ::Storage.transport_name(transport)
      else
        return ""
      end
    end

    def new_tree_view
      return ExpertPartitioner::DiskTreeView.new(self)
    end
  end

  class Md
    def table_icon
      return make_icon_cell(ExpertPartitioner::Icons::MD, "MD RAID")
    end

    def table_md_level
      return ::Storage.md_level_name(md_level)
    end

    def new_tree_view
      return ExpertPartitioner::MdTreeView.new(self)
    end
  end

  class Partition
    def table_icon
      return make_icon_cell(ExpertPartitioner::Icons::PARTITION, "Partition")
    end

    def new_tree_view
      return ExpertPartitioner::PartitionTreeView.new(self)
    end
  end

  class LvmPv
    def table_icon
      return make_icon_cell(ExpertPartitioner::Icons::LVM_PV, "LVM PV")
    end

    def table_blk_device_name
      return blk_device.name
    end
  end

  class LvmVg
    def table_icon
      return make_icon_cell(ExpertPartitioner::Icons::LVM_VG, "LVM VG")
    end

    def table_vg_name
      return vg_name
    end

    def new_tree_view
      return ExpertPartitioner::LvmVgTreeView.new(self)
    end
  end

  class LvmLv
    def table_icon
      return make_icon_cell(ExpertPartitioner::Icons::LVM_LV, "LVM LV")
    end

    def table_lv_name
      return lv_name
    end

    def table_stripe_info
      if stripes != 0
        return "#{stripes} (#{::Storage.byte_to_humanstring(stripe_size, false, 2, false)})"
      else
        return ""
      end
    end

    def new_tree_view
      return ExpertPartitioner::LvmLvTreeView.new(self)
    end
  end

  class Encryption
    def table_icon
      return make_icon_cell(ExpertPartitioner::Icons::ENCRYPTION, "Encryption")
    end
  end

  class Luks
    def table_icon
      return make_icon_cell(ExpertPartitioner::Icons::ENCRYPTION, "LUKS")
    end

    def new_tree_view
      return ExpertPartitioner::LuksTreeView.new(self)
    end
  end

  class Bcache
    def table_icon
      return make_icon_cell(ExpertPartitioner::Icons::BCACHE, "Bcache")
    end

    def new_tree_view
      return ExpertPartitioner::BcacheTreeView.new(self)
    end
  end

  class BcacheCset
    def table_icon
      return make_icon_cell(ExpertPartitioner::Icons::BCACHE_CSET, "Bcache Cset")
    end

    def table_uuid
      return uuid
    end

    def new_tree_view
      return ExpertPartitioner::BcacheCsetTreeView.new(self)
    end
  end

  class Filesystem
    def table_icon
      return make_icon_cell(ExpertPartitioner::Icons::FILESYSTEM, "Filesystem")
    end

    def table_filesystem
      return to_s
    end

    def table_mountpoint
      if !mountpoints.empty?
        return mountpoints.to_a[0]
      else
        return ""
      end
    end

    def table_mount_by
      return ::Storage.mount_by_name(mount_by)
    end

    def table_label
      return label
    end

    def table_uuid
      return uuid
    end
  end
end
