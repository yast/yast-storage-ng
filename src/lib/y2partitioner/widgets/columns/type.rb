# Copyright (c) [2020] SUSE LLC
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
require "y2partitioner/icons"
require "y2partitioner/widgets/columns/base"

module Y2Partitioner
  module Widgets
    module Columns
      # Widget for displaying the `Type` column, which actually is a kind of device description
      class Type < Base
        # Device icons based on its type
        #
        # @see #icon
        DEVICE_ICONS = {
          bcache:    Icons::BCACHE,
          disk:      Icons::HD,
          dasd:      Icons::HD,
          multipath: Icons::MULTIPATH,
          nfs:       Icons::NFS,
          partition: Icons::HD_PART,
          raid:      Icons::RAID,
          lvm_vg:    Icons::LVM,
          lvm_lv:    Icons::LVM_LV,
          btrfs:     Icons::BTRFS
        }
        private_constant :DEVICE_ICONS

        # Default labels based on the device type
        #
        # @see #default_label
        DEVICE_LABELS = {
          bcache:         N_("Bcache"),
          disk:           N_("Disk"),
          dasd:           N_("Disk"),
          multipath:      N_("Multipath"),
          nfs:            N_("NFS"),
          bios_raid:      N_("BIOS RAID"),
          software_raid:  N_("RAID"),
          lvm_pv:         N_("PV"),
          lvm_vg:         N_("LVM"),
          lvm_thin:       N_("Thin LV"),
          lvm_thin_pool:  N_("Thin Pool"),
          lvm_raid:       N_("RAID LV"),
          lvm_cache:      N_("Cache LV"),
          lvm_cache_pool: N_("Cache Pool"),
          lvm_writecache: N_("Writecache LV"),
          lvm_snapshot:   N_("Snapshot LV"),
          lvm_mirror:     N_("Mirror LV"),
          lvm_lv:         N_("LV"),
          stray:          N_("Xen"),
          partition:      N_("Partition")
        }
        private_constant :DEVICE_LABELS

        # @see Columns::Base#title
        def title
          # TRANSLATORS: table header, type of disk or partition. Can be longer. E.g. "Linux swap"
          _("Type")
        end

        # @see Columns::Base#value_for
        def value_for(device)
          cell(
            Icon(device_icon(device)),
            device_label(device)
          )
        end

        private

        # The icon name for the device type
        #
        # @see DEVICE_ICONS
        #
        # @param device [Y2Storage::Device, Y2Storage::LvmPv, Y2Storage::SimpleEtcFstabEntry]
        # @return [String]
        def device_icon(device)
          return fstab_device_icon(device) if fstab_entry?(device)
          return lvm_pv_icon(device) if device.is?(:lvm_pv)

          type = DEVICE_ICONS.keys.find { |k| device.is?(k) }
          type ? DEVICE_ICONS[type] : Icons::DEFAULT_DEVICE
        end

        # The icon for the device of an LVM physical volume
        #
        # @param lvm_pv [Y2Storage::LvmPv]
        # @return [String] the #device_icon if device is found in the system; empty string otherwise
        def lvm_pv_icon(lvm_pv)
          device_icon(lvm_pv.plain_blk_device)
        end

        # The icon for the device in the given fstab entry
        #
        # @param fstab_entry [Y2Storage::SimpleEtcFstabEntry]
        # @return [String] the #device_icon if device is found in the system; empty string otherwise
        def fstab_device_icon(fstab_entry)
          device = fstab_entry.device(system_graph)
          device ? device_icon(device) : ""
        end

        # A text describing the given device
        #
        # @see DEVICE_ICONS
        #
        # @param device [Y2Storage::Device, Y2Storage::LvmPv, Y2Storage::SimpleEtcFstabEntry]
        # @return [String]
        def device_label(device)
          return fstab_device_label(device) if fstab_entry?(device)
          return device.type.to_human_string if device.is?(:filesystem)
          return default_label(device) if device.is?(:lvm_vg)
          return snapshot_type_label(device) if device.is?(:lvm_snapshot)

          formatted_device_type_label(device) || unformatted_device_type_label(device)
        end

        # Label for the device in the given fstab entry
        #
        # @param fstab_entry [Y2Storage::SimpleEtcFstabEntry]
        # @return [String] the #device_label if device is found in the system; empty string otherwise
        def fstab_device_label(fstab_entry)
          device = fstab_entry.device(system_graph)
          device ? device_label(device) : ""
        end

        # Label for a formatted device (e.g., Ext4 LVM, XFS RAID, Swap Partition, etc)
        #
        # @return [String, nil] label if the device has a filesystem; nil otherwise
        def formatted_device_type_label(device)
          fs = filesystem_for(device)

          return nil unless fs

          if device.journal?
            journal_type_label(fs)
          elsif show_multidevice_type_label?(fs)
            multidevice_type_label(fs)
          else
            # TRANSLATORS: %{fs_type} is the filesystem type. I.e., FAT, Ext4, etc
            #              %{device_label} is the device label. I.e., Partition, Disk, etc
            format(
              _("%{fs_type} %{device_label}"),
              fs_type:      fs_type(device, fs),
              device_label: default_label(device)
            )
          end
        end

        # The filesystem type representation (FAT, Ext4, etc)
        #
        # @return [String]
        def fs_type(device, filesystem)
          if device.is?(:partition) && device.efi_system?
            device.id.to_human_string
          else
            filesystem.type.to_human_string
          end
        end

        # Label for unformatted device (e.g., LVM, RAID, Partition, etc)
        #
        # @return [String]
        def unformatted_device_type_label(device)
          if device.lvm_pv
            lvm_pv_type_label(device.lvm_pv)
          elsif device.md
            part_of_label(device.md)
          elsif device.bcache
            part_of_label(device.bcache)
          elsif device.in_bcache_cset
            bcache_cset_label
          else
            default_unformatted_label(device)
          end
        end

        # Label when the device is a LVM physical volume
        #
        # @param lvm_pv [Y2Storage::LvmPv]
        # @return [String]
        def lvm_pv_type_label(lvm_pv)
          vg = lvm_pv.lvm_vg

          return _("Unused LVM PV") if vg.nil?
          return _("PV of LVM") if vg.basename.empty?

          # TRANSLATORS: %s is the volume group name. E.g., "vg0"
          format(_("PV of %s"), vg.basename)
        end

        # Label for an LVM snapshot device
        #
        # @param lvm_snapshot [Y2Storage::LvmLv]
        # @return [String]
        def snapshot_type_label(lvm_snapshot)
          label =
            if lvm_snapshot.is?(:lvm_thin_snapshot)
              # TRANSLATORS: %{origin} is replaced by an LVM logical volumme name
              # (e.g., /dev/vg0/user-data)
              _("Thin Snapshot of %{origin}")
            else
              # TRANSLATORS: %{origin} is replaced by an LVM logical volumme name
              # (e.g., /dev/vg0/user-data)
              _("Snapshot of %{origin}")
            end

          format(label, origin: lvm_snapshot.origin.lv_name)
        end

        # Label when the device holds a journal
        #
        # @param filesystem [Y2Storage::BlkFilesystem]
        # @return [String]
        def journal_type_label(filesystem)
          data_device = filesystem.blk_devices.find { |d| !d.journal? }

          # TRANSLATORS: %{fs_type} is the filesystem type. E.g., Btrfs, Ext4, etc.
          #              %{data_device_name} is the data device name. E.g., sda1
          format(
            _("%{fs_type} Journal (%{data_device_name})"),
            fs_type:          filesystem.type.to_human_string,
            data_device_name: data_device.basename
          )
        end

        # Label when the device belongs to a multi-device filesystem
        #
        # @param filesystem [Y2Storage::BlkFilesystem]
        # @return [String]
        def multidevice_type_label(filesystem)
          # TRANSLATORS: %{fs_name} is the filesystem name. E.g., Btrfs, Ext4, etc.
          #              %{blk_device_name} is a device base name. E.g., sda1...
          format(
            _("Part of %{fs_name} %{blk_device_name}"),
            fs_name:         filesystem.type,
            blk_device_name: filesystem.blk_device_basename
          )
        end

        # Label when the device is used as caching device in a bcache
        #
        # @return [String]
        def bcache_cset_label
          # TRANSLATORS: an special type of device
          _("Bcache cache")
        end

        # Label when the device is part of another one, like Bcache or RAID
        #
        # @param ancestor_device [Y2Storage::BlkDevice]
        # @return [String]
        def part_of_label(ancestor_device)
          format(_("Part of %s"), ancestor_device.basename)
        end

        # Default label when device is unformatted
        #
        # @return [String]
        def default_unformatted_label(device)
          data = [device.vendor, device.model].compact

          return data.join("-") unless data.empty?
          return device.id.to_human_string if device.respond_to?(:id)

          default_label(device)
        end

        # Default label for the device
        #
        # @see DEVICE_LABELS
        #
        # @param device [Y2Storage::Device]
        # @return [String]
        def default_label(device)
          type = DEVICE_LABELS.keys.find { |k| device.is?(k) }

          return "" if type.nil?

          _(DEVICE_LABELS[type])
        end

        # Whether the "Part of *fs.type*" label should be displayed
        #
        # The Ext3/4 filesystem could be detected as a multi-device filesystem
        # when its journal is placed in an external device. However, we do not
        # want to display "Part of ..." for them because we know that data
        # partition is over a single device.
        #
        # @see #formatted_device_type_label
        # @return [Boolean] true if the filesystem is multi-device BUT not an Ext3/4 one
        def show_multidevice_type_label?(filesystem)
          return false unless filesystem
          return false if filesystem.type.is?(:ext3, :ext4)

          filesystem.multidevice?
        end
      end
    end
  end
end
