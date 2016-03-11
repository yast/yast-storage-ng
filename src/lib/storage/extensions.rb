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
      size:            N_("Size"),
      partition_table: N_("Partition Table"),
      filesystem:      N_("Filesystem"),
      mountpoint:      N_("Mount Point"),
      label:           N_("Label"),
      transport:       N_("Transport"),
      mount_by:        N_("Mount By"),
      md_level:        N_("RAID Level"),
      spare:           N_("Spare"),
      faulty:          N_("Faulty")
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
      return make_icon_cell(Icons::DEVICE, "Device")
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

    def table_label
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
      return ::Storage.byte_to_humanstring(1024 * size_k, false, 2, false)
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
  end

  class Md
    def table_icon
      return make_icon_cell(ExpertPartitioner::Icons::MD, "MD RAID")
    end

    def table_md_level
      return ::Storage.md_level_name(md_level)
    end
  end

  class Partition
    def table_icon
      return make_icon_cell(ExpertPartitioner::Icons::PARTITION, "Partition")
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
  end
end
