
require "storage"

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

        end

      end)

    end


    def table_row(fields)
      Item(Id(sid), *fields.map { |field| send("table_#{field}") })
    end

    def table_sid()
      return sid
    end

    def table_icon()
      return ""
    end

    def table_icon(icon, text)
      return Yast::Term.new(:cell, Yast::Term.new(:icon, "#{Yast::Directory.icondir}/22x22/apps/#{icon}.png"), text)
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

  end


  class Disk

    def table_icon()
      return super("yast-disk", "Disk")
    end

    def table_partition_table()
      return partition_table.to_s
    rescue ::Storage::WrongNumberOfChildren, ::Storage::DeviceHasWrongType
      return ""
    end

    def table_transport()
      if transport != TUNKNOWN
        return ::Storage::transport_name(transport)
      else
        return ""
      end
    end

  end


  class Partition

    def table_icon()
      return super("yast-partitioning", "Partition")
    end

  end


  class Filesystem

    def table_icon()
      return super("yast-nfs", "Filesystem")
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
