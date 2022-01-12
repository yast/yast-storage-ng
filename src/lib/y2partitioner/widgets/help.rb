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

Yast.import "Mode"

module Y2Partitioner
  module Widgets
    # rubocop:disable Metrics/ModuleLength
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

        btrfs_exclusive:           N_("<b>Excl. Size</b> shows the size of the exclusive space\n" \
                                      "of the BtrFS subvolume. This is the space that would be\n" \
                                      "freed by deleting the subvolume. Known and displayed only\n" \
                                      "if quotas were active for the corresponding BtrFS file\n" \
                                      "system during the hardware detection."),

        btrfs_referenced:          N_("<b>Ref. Size</b> shows the size of the referenced space\n" \
                                      "of the BtrFS subvolume. This is the total size of all files\n" \
                                      "in the subvolume. Known and displayed only if quotas were\n" \
                                      "active for the corresponding BtrFS file system during the\n" \
                                      "hardware detection."),

        btrfs_rfer_limit:          N_("<b>Size Limit</b> shows the max size of the referenced\n" \
                                      "space for the BtrFS subvolume, if BtrFS quotas are active in\n" \
                                      "the corresponding BtrFS file system."),

        bus:                       N_("<b>Bus</b> shows how the device is connected to\n" \
                                      "the system. This field can be empty, e.g. for multipath disks."),

        chunk_size:                N_("<b>Chunk Size</b> shows the chunk size for RAID\ndevices."),

        cyl_size:                  N_("<b>Cylinder Size</b> shows the size of the\ncylinders " \
                                      "of the hard disk."),

        sectors:                   N_("<b>Number of Sectors</b> shows how many sectors the hard " \
                                      "disk has."),

        sector_size:               N_("<b>Sector Size</b> shows the size of the\n" \
                                      "sectors of the hard disk."),

        device:                    N_("<b>Device</b> shows the name to identify the device, e.g. the " \
                                      "kernel name when it applies."),

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

        mount_options:             N_("<b>Mount Options</b> shows the options used to mount the " \
                                      "volume, typically specified at <tt>/etc/fstab</tt>."),

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

        snapshots:                 N_("<b>Snapshots</b> shows the snapshots, if any, for an LVM " \
                                      "logical volume."),

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

        journal:                   N_("<b>Journal Device</b> shows the device holding the " \
                                      "external journal."),

        btrfs_devices:             N_("<b>Devices</b> shows the kernel name of the devices used by a "\
                                      "Btrfs file system."),

        btrfs_metadata_raid_level: N_("<b>Metadata RAID Level</b> shows the RAID level for the Btrfs " \
                                      "metadata."),

        btrfs_data_raid_level:     N_("<b>Data RAID Level</b> shows the RAID level for the Btrfs data."),

        nfs_version:               N_("<b>NFS Version</b> shows the version of the protocol used to " \
                                      "connect to the server. It may happen that some NFS share is " \
                                      "mounted using an old method to specify the protocol version, " \
                                      "like the usage of 'nfs4' as file system type or the usage of " \
                                      "'minorversion' in the mount options. Those methods do not " \
                                      "longer work as they used to. So if such circumstance is " \
                                      "detected, the real used version is displayed next to a warning " \
                                      "message. Those entries can be edited to make sure they use " \
                                      "more current ways of specifying the version.")
      }.freeze

      UNMOUNTED_TEXT = N_("An asterisk (*) after the mount point\n" \
                          "indicates a file system that is currently not mounted (for example, " \
                          "because it\nhas the <tt>noauto</tt> option set in <tt>/etc/fstab</tt>).")

      # help texts that are appended to the common help only in Mode.normal
      NORMAL_MODE_TEXTS = {
        mount_by:        N_("A question mark (?) indicates that\n" \
                            "the file system is not listed in <tt>/etc/fstab</tt>. It is either " \
                            "mounted\nmanually or by some automount system. When changing " \
                            "settings for this volume\n" \
                            "YaST will not update <tt>/etc/fstab</tt>.\n"),

        mount_point:     UNMOUNTED_TEXT,

        nfs_mount_point: UNMOUNTED_TEXT
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
    # rubocop:enable Metrics/ModuleLength
  end
end
