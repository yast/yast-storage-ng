# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "yast/i18n"
require "y2partitioner/device_graphs"
require "y2storage"

module Y2Partitioner
  module Actions
    module Controllers
      # This class stores information about the fstab files read from all
      # the filesystem in the system. It also saves information about the
      # selected fstab to be used to import mount points.
      class Fstabs
        include Yast::I18n

        # @return [Y2Storage::Fstab] fstab file selected to import mount points
        attr_accessor :selected_fstab

        # Constructor
        def initialize
          textdomain "storage"
        end

        # All fstab files found in the system
        #
        # @return [Array<Y2Storage::Fstab>]
        def fstabs
          disk_analyzer.fstabs
        end

        # Selects the previous fstab
        #
        # The current selected fstab does not change if it already is the first one.
        #
        # @return [Y2Storage::Fstab]
        def select_prev_fstab
          current_index = fstabs.index(selected_fstab)
          prev_index = [0, current_index - 1].max

          @selected_fstab = fstabs.at(prev_index)
        end

        # Selects the next fstab
        #
        # The current selected fstab does not change if it already is the last one.
        #
        # @return [Y2Storage::Fstab]
        def select_next_fstab
          current_index = fstabs.index(selected_fstab)
          next_index = [fstabs.size - 1, current_index + 1].min

          @selected_fstab = fstabs.at(next_index)
        end

        # Checks whether the selected fstab is the first one
        #
        # @return [Boolean]
        def selected_first_fstab?
          selected_fstab == fstabs.first
        end

        # Checks whether the selected fstab is the last one
        #
        # @return [Boolean]
        def selected_last_fstab?
          selected_fstab == fstabs.last
        end

        # Errors in the selected fstab
        #
        # @see #not_importable_entries_error
        #
        # @return [Array<String>]
        def selected_fstab_errors
          [not_importable_entries_error].compact
        end

        # Imports mount points from the selected fstab
        #
        # Before importing, the current devicegraph is reset to the system one.
        def import_mount_points
          reset_current_graph
          importable_entries.each { |e| import_mount_point(e) }
          Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing(current_graph)
        end

      private

        # System devicegraph
        #
        # @return [Y2Storage::Devicegraph]
        def system_graph
          DeviceGraphs.instance.system
        end

        # Current devicegraph
        #
        # @return [Y2Storage::Devicegraph]
        def current_graph
          DeviceGraphs.instance.current
        end

        # Disk analyzer for the system devicegraph
        #
        # @return [Y2Storage::DiskAnalyzer]
        def disk_analyzer
          DeviceGraphs.instance.disk_analyzer
        end

        # Error when some entries in the selected fstab cannot be imported
        #
        # An entry cannot be imported when the device is not found or it is used
        # by other device (e.g., used by LVM or MD RAID).
        #
        # @return [String, nil] nil if all entries can be imported
        def not_importable_entries_error
          entries = not_importable_entries
          return nil if entries.empty?

          mount_points = entries.map(&:mount_point).join("\n")

          # TRANSLATORS: %{mount_points} is replaced by a list of mount points, please
          # do not modify it.
          format(_("The following mount points cannot be imported:\n%{mount_points}"),
            mount_points: mount_points)
        end

        # Entries in the current selected fstab that can be imported
        #
        # @see #can_be_imported?
        #
        # @return[Array<Y2Storage::SimpleEtcFstabEntry>]
        def importable_entries
          selected_fstab.filesystem_entries.select { |e| can_be_imported?(e) }
        end

        # Entries in the current selected fstab that cannot be imported
        #
        # @see #can_be_imported?
        #
        # @return[Array<Y2Storage::SimpleEtcFstabEntry>]
        def not_importable_entries
          selected_fstab.filesystem_entries - importable_entries
        end

        # Whether a fstab entry can be imported
        #
        # An entry can be imported when the device is known and it is not used
        # by other device (e.g., used by LVM or MD RAID), or it is a known NFS.
        # Moreover, the entry must have a known filesystem type.
        #
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        # @return [Boolean]
        def can_be_imported?(entry)
          device = entry.device(system_graph)
          return false unless device

          # Checks whether the device is actually a filesystem (i.e., NFS)
          return true if device.is?(:filesystem)

          known_fs_type?(entry) && can_be_formatted?(device)
        end

        # Whether a fstab entry has a known filesystem type
        #
        # In case the fstab entry contains "auto" or "none" in the third
        # field (fs_vfstype), the filesystem type cannot be determined.
        #
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        # @return [Boolean]
        def known_fs_type?(entry)
          !entry.fs_type.is?(:auto) && !entry.fs_type.is?(:unknown)
        end

        # Whether a device can be formatted
        #
        # A device can be formatted if it is already formatted or it is not used by
        # another device (e.g., LVM or MD RAID).
        #
        # @param device [Y2Storage::BlkDevice]
        # @return [Boolean]
        def can_be_formatted?(device)
          unused?(device) ||
            device.formatted? ||
            (device.encrypted? && unused?(device.encryption))
        end

        # Whether the device has not been used yet
        #
        # @param device [Y2Storage::BlkDevice]
        # @return [Boolean]
        def unused?(device)
          device.descendants.empty?
        end

        # Initializes current devicegraph with system
        def reset_current_graph
          DeviceGraphs.instance.current = system_graph.dup
        end

        # Imports the mount point of a fstab entry
        #
        # The device in the fstab entry (first field) is formatted using the fileystem type
        # indicated in the entry. In case the device is not a block device (e.g., NFS), the
        # device is not formatted and only the mount point and mount options are assigned.
        #
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        def import_mount_point(entry)
          device = entry.device(current_graph)
          return unless device

          if device.is?(:blk_device)
            filesystem = format_device(device, entry.fs_type)
            create_mount_point(filesystem, entry)
            setup_blk_filesystem(filesystem)
          else
            create_mount_point(device, entry)
          end
        end

        # Formats the device indicated in the fstab entry
        #
        # @param device [Y2Storage::BlkDevice]
        # @param fs_type [Y2Storage::Filesystems::Type]
        #
        # @return [Y2Storage::Filesystems::Base]
        def format_device(device, fs_type)
          device.delete_filesystem
          device.create_filesystem(fs_type)
        end

        # Creates the #{Y2Storage::MountPoint} object based on the imported
        # fstab entry.
        #
        # @param filesystem [Y2Storage::Filesystems::Base]
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        def create_mount_point(filesystem, entry)
          filesystem.mount_path = entry.mount_point
          filesystem.mount_point.mount_options = entry.mount_options if entry.mount_options.any?
        end

        # Performs any additional final step needed for the new block
        # filesystem (Btrfs stuff, so far)
        #
        # @param filesystem [Y2Storage::Filesystems::BlkFilesystem]
        def setup_blk_filesystem(filesystem)
          if filesystem.can_configure_snapper?
            filesystem.configure_snapper = filesystem.default_configure_snapper?
          end
          filesystem.setup_default_btrfs_subvolumes if filesystem.supports_btrfs_subvolumes?
        end
      end
    end
  end
end
