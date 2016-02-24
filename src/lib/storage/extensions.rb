
require "storage"
require "expert-partitioner/icons"

include Yast::UIShortcuts


module Storage


  def self.silence
    silencer = ::Storage::Silencer.new()
    yield
  ensure
    silencer.turn_off
  end


  class Device

    def self.table_header(fields)

      return Header(*fields.map do |field|

        case field

        when :sid
          _("Storage ID")

        when :icon
          _("Icon")

        when :name
          _("Name")

        when :size
          Right(_("Size"))

        when :partition_table
          _("Partition Table")

        when :filesystem
          _("Filesystem")

        when :mountpoint
          _("Mount Point")

        when :label
          _("Label")

        when :transport
          _("Transport")

        when :mount_by
          _("Mount By")

        when :md_level
          _("RAID Level")

        when :spare
          _("Spare")

        end

      end)

    end


    def make_icon_cell(icon, text)
      return Yast::Term.new(:cell, Yast::Term.new(:icon, "#{Yast::Directory.icondir}/22x22/apps/#{icon}"), text)
    end


    def table_row(fields)
      Item(Id(sid), *fields.map { |field| send("table_#{field}") })
    end

    def table_sid()
      return sid
    end

    def table_icon()
      return make_icon_cell(Icons::DEVICE, "Device")
    end

    def table_name()
      return ""
    end

    def table_size()
      return ""
    end

    def table_partition_table()
      return ""
    end

    def table_filesystem()
      return ""
    end

    def table_label()
      return ""
    end

    def table_transport()
      return ""
    end

    def table_mount_by()
      return ""
    end

    def table_md_level()
      return ""
    end

    def table_spare()
      return ""
    end

  end


  class BlkDevice

    def table_name()
      return name
    end

    def table_size()
      return ::Storage::byte_to_humanstring(1024 * size_k, false, 2, false)
    end

    def table_filesystem()
      return filesystem.table_filesystem
    rescue ::Storage::WrongNumberOfChildren, ::Storage::DeviceHasWrongType
      return ""
    end

    def table_mountpoint()
      return filesystem.table_mountpoint
    rescue ::Storage::WrongNumberOfChildren, ::Storage::DeviceHasWrongType
      return ""
    end

    def table_spare()
      spare = out_holders.to_a.any? do |holder|
        if ::Storage::md_user?(holder)
          ::Storage::to_md_user(holder).spare?
        end
      end
      spare ? "Spare" : ""
    end

  end


  class Partitionable

    def table_partition_table()
      return ::Storage::pt_type_name(partition_table.type)
    rescue ::Storage::WrongNumberOfChildren, ::Storage::DeviceHasWrongType
      return ""
    end

  end


  class Disk

    def table_icon()
      return make_icon_cell(ExpertPartitioner::Icons::DISK, "Disk")
    end

    def table_transport()
      if transport != Transport_UNKNOWN
        return ::Storage::transport_name(transport)
      else
        return ""
      end
    end

  end


  class Md

    def table_icon()
      return make_icon_cell(ExpertPartitioner::Icons::MD, "MD RAID")
    end

    def table_md_level()
      return ::Storage::md_level_name(md_level)
    end

  end


  class Partition

    def table_icon()
      return make_icon_cell(ExpertPartitioner::Icons::PARTITION, "Partition")
    end

  end


  class Filesystem

    def table_icon()
      return make_icon_cell(ExpertPartitioner::Icons::FILESYSTEM, "Filesystem")
    end

    def table_filesystem()
      return to_s
    end

    def table_mountpoint()
      if !mountpoints.empty?
        return mountpoints.to_a[0]
      else
        return ""
      end
    end

    def table_mount_by()
      return ::Storage::mount_by_name(mount_by)
    end

    def table_label()
      return label
    end

  end


end
