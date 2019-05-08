require "yast"

Yast.import "Mode"

module Y2Partitioner
  module Widgets
    # Helper methods for generating widget helps.
    module Help
      extend Yast::I18n

      def included(_target)
        textdomain "storage"
      end

      # helptexts for table column and overview entry
      TEXTS = {
        bios_id:                   N_("<b>BIOS ID</b> shows the BIOS ID of the hard\n" \
                                      "disk. This field can be empty."),

        bus:                       N_("<b>Bus</b> shows how the device is connected to\n" \
                                      "the system. This field can be empty, e.g. for multipath disks."),

        chunk_size:                N_("<b>Chunk Size</b> shows the chunk size for RAID\ndevices."),

        cyl_size:                  N_("<b>Cylinder Size</b> shows the size of the\ncylinders " \
          "of the hard disk."),

        sectors:                   N_("<b>Number of Sectors</b> shows how many sectors the hard " \
                                      "disk has."),

        sector_size:               N_("<b>Sector Size</b> shows the size of the\n" \
                                      "sectors of the hard disk."),

        device:                    N_("<b>Device</b> shows the kernel name of the\ndevice."),

        disk_label:                N_("<b>Partition Table</b> shows the partition table\n" \
                                      "type of the disk, e.g <tt>MS-DOS</tt> or <tt>GPT</tt>."),

        encrypted:                 N_("<b>Encrypted</b> shows whether the device is\nencrypted."),

        end:                       N_("<b>End</b> shows the end block of\nthe partition."),

        fc_fcp_lun:                N_("<b>LUN</b> shows the Logical Unit Number for\n" \
                                      "Fibre Channel disks."),

        fc_port_id:                N_("<b>Port ID</b> shows the port id for Fibre\nChannel disks."),

        fc_wwpn:                   N_("<b>WWPN</b> shows the World Wide Port Name for\n" \
                                      "Fibre Channel disks."),

        file_path:                 N_("<b>File Path</b> shows the path of the file for\nan encrypted " \
          "loop device."),

        format:                    N_("<b>Format</b> shows some flags: <tt>F</tt>\n" \
                                      "means the device is selected to be formatted."),

        partition_id:              N_("<b>Partition ID</b> shows the partition id."),

        fs_type:                   N_("<b>FS Type</b> shows the file system type."),

        label:                     N_("<b>Label</b> shows the label of the file\nsystem."),

        lvm_metadata:              N_("<b>Metadata</b> shows the LVM metadata type for\n" \
                                      "volume groups."),

        model:                     N_("<b>Model</b> shows the device model."),

        mount_by:                  N_("<b>Mount by</b> indicates how the file system\n" \
                                      "is mounted: (Kernel) by kernel name, (Label) by " \
                                      "file system label, (UUID) by\n file system " \
                                      "UUID, (ID) by device ID, and (Path) by device path.\n"),

        mount_point:               N_("<b>Mount Point</b> shows where the file system\nis mounted."),

        num_cyl:                   N_("<b>Number of Cylinders</b> shows how many\n" \
                                      "cylinders the hard disk has."),

        parity_algorithm:          N_("<b>Parity Algorithm</b> shows the parity\n" \
                                      "algorithm for RAID devices with RAID type 5, 6 or 10."),

        pe_size:                   N_("<b>PE Size</b> shows the physical extent size\n" \
                                      "for LVM volume groups."),

        raid_version:              N_("<b>RAID Version</b> shows the RAID version."),

        raid_type:                 N_("<b>RAID Type</b> shows the RAID type, also\n" \
                                      "called RAID level, for RAID devices."),

        size:                      N_("<b>Size</b> shows the size of the device."),

        start:                     N_("<b>Start</b> shows the start block\nof the partition."),

        stripes:                   N_("<b>Stripes</b> shows the stripe number for LVM\n" \
                                      "logical volumes and, if greater than one, the stripe size " \
                                      "in parenthesis."),

        type:                      N_("<b>Type</b> gives a general overview about the\ndevice type."),

        udev_id:                   N_("<b>Device ID</b> shows the persistent device\n" \
                                      "IDs. This field can be empty."),

        udev_path:                 N_("<b>Device Path</b> shows the persistent device\n" \
                                      "path. This field can be empty."),

        used_by:                   N_("<b>Used By</b> shows if a device is used by\n" \
                                      "e.g. RAID or LVM. If not, this column is empty."),

        uuid:                      N_("<b>UUID</b> shows the Universally Unique\n" \
                                      "Identifier of the file system."),

        vendor:                    N_("<b>Vendor</b> shows the device vendor."),

        backing_device:            N_("<b>Backing Device</b> shows the device used as backing " \
                                      "device for bcache."),

        caching_uuid:              N_("<b>Caching UUID</b> shows the UUID of the used caching set. " \
                                      "This field is empty if no caching is used."),

        caching_device:            N_("<b>Caching Device</b> shows the device used for caching. " \
                                      "This field is empty if no caching is used."),

        cache_mode:                N_("<b>Cache Mode</b> shows the operating mode for bcache. " \
                                      "Currently there are four supported modes: Writethrough, " \
                                      "Writeback, Writearound and None."),

        btrfs_devices:             N_("<b>Devices</b> shows the kernel name of the devices used by a "\
                                      "Btrfs file system."),
        btrfs_metadata_raid_level: N_("<b>Metadata RAID Level</b> shows the RAID level for the Btrfs " \
                                      "metadata."),

        btrfs_data_raid_level:     N_("<b>Data RAID Level</b> shows the RAID level for the Btrfs data.")
      }.freeze

      # help texts that are appended to the common help only in Mode.normal
      NORMAL_MODE_TEXTS = {
        mount_by:    N_("A question mark (?) indicates that\n" \
                  "the file system is not listed in <tt>/etc/fstab</tt>. It is either mounted\n" \
                  "manually or by some automount system. When changing settings for this volume\n" \
                  "YaST will not update <tt>/etc/fstab</tt>.\n"),

        mount_point: N_("An asterisk (*) after the mount point\n" \
            "indicates a file system that is currently not mounted (for example, " \
            "because it\nhas the <tt>noauto</tt> option set in <tt>/etc/fstab</tt>).")
      }.freeze

      # return translated text for given field in table or description
      # TODO: old yast2-storage method, need some cleaning
      def helptext_for(field)
        text = TEXTS[field]
        return "" if text.nil?

        ret = "<p>"
        ret << _(text)
        if Yast::Mode.normal
          text2 = NORMAL_MODE_TEXTS[field]
          ret << " " << _(text2) if text2
        end

        ret << "</p>"
      end
    end
  end
end
