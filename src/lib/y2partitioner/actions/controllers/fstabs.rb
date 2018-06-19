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
require "y2storage/storage_manager"
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

        # @return [Boolean] whether the system volumes must be formatted
        #
        # @note A volume is considered as "system volume" when it is mounted in certain
        #   specific mount point like /, /usr, etc. See {#system_mount_points}.
        attr_accessor :format_system_volumes
        alias_method :format_system_volumes?, :format_system_volumes

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

        # System mount points are taken from old code, see
        # https://github.com/yast/yast-storage/blob/master_old/src/modules/FileSystems.rb#L438
        SYSTEM_MOUNT_POINTS = ["/", "/usr", "/var", "/opt", "/boot"].freeze
        private_constant :SYSTEM_MOUNT_POINTS

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

        # Current system architecture
        #
        # @return [Storage::Arch]
        def arch
          @arch ||= Y2Storage::StorageManager.instance.arch
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
        # Moreover, in case the device must be formatted, the entry also must
        # indicate a known filesystem type.
        #
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        # @return [Boolean]
        def can_be_imported?(entry)
          device = entry_device(entry, system_graph)
          return false unless device

          return true unless must_be_formatted?(device, entry.mount_point)

          known_fs_type?(entry) && can_be_formatted?(device)
        end

        # Whether the device must be formatted in order to import the mount point
        #
        # A device must be formatted when it is not currently formatted or it is a device
        # that should be mounted over a system mount point (see #{system_mount_points}).
        # For this last case, the option to format system volumes should be selected
        # (see {#format_system_volumes?}).
        #
        # @param device [Y2Storage::BlkDevice, Y2Storage::Filesystems::Base]
        # @param mount_point [String] mount point of fstab entry
        #
        # @return [Boolean]
        def must_be_formatted?(device, mount_point)
          # In case the device is a filesystem (i.e., NFS), the device should not be formatted.
          return false if device.is?(:filesystem)

          !device.formatted? ||
            (system_mount_point?(mount_point) && format_system_volumes?)
        end

        # Whether the mount point is included in the list of system mount points
        #
        # @param mount_point [String] mount point of fstab entry
        # @return [Boolean]
        def system_mount_point?(mount_point)
          system_mount_points.include?(mount_point)
        end

        # Mount points considered as system mount points
        #
        # The list of system mount points are taken from old code, see
        # https://github.com/yast/yast-storage/blob/master_old/src/modules/FileSystems.rb#L438
        #
        # @return [Array<String>]
        def system_mount_points
          return @system_mount_points if @system_mount_points

          @system_mount_points = SYSTEM_MOUNT_POINTS.dup
          @system_mount_points << "/boot/zipl" if arch.s390?
          @system_mount_points
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
        # another device (e.g., LVM or MD RAID). Moreover, in case of a encryption
        # device, the device must be active.
        #
        # @param device [Y2Storage::BlkDevice]
        # @return [Boolean]
        def can_be_formatted?(device)
          return false if device.is?(:encryption) && !device.active?

          unused?(device) || device.formatted?
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
        # When the device needs to be formatted (see {#must_be_formatted?}), the filesystem type
        # indicated in the entry is used. In case the device is not a block device (e.g., NFS),
        # the device is not formatted and only the mount point and mount options are assigned.
        #
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        def import_mount_point(entry)
          device = entry_device(entry, current_graph)
          return unless device

          if must_be_formatted?(device, entry.mount_point)
            filesystem = format_device(device, entry.fs_type)
            create_mount_point(filesystem, entry)
            setup_blk_filesystem(filesystem)
          else
            filesystem = device.is?(:filesystem) ? device : device.filesystem
            create_mount_point(filesystem, entry)
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

        # Device indicated in the fstab entry
        #
        # When the device name in the fstab entry corresponds to a encryption device, the device
        # could not be found by that fstab name. In general, the encryptions might be probed with
        # a different name, so before searching for the device, the devicegraph is modified to
        # set the encryption names from the crypttab file. That changes are made in a temporary
        # devicegraph, so the original one is never altered.
        #
        # @see #devicegraph_with_fixed_encryptions
        #
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        # @param devicegraph [Y2Storage::Devicegraph]
        #
        # @return [Y2Storage::BlkDevice, Y2Storage::Filesystems::Nfs, nil] nil if the device is
        #   not found in the devicegraph.
        def entry_device(entry, devicegraph)
          device = entry.device(devicegraph_with_fixed_encryptions(devicegraph))
          device ? devicegraph.find_device(device.sid) : nil
        end

        # Duplicates the given devicegraph and modifies it by setting the encryption names
        # from the crypttab file
        #
        # @see #crypttab
        #
        # @param devicegraph [Y2Storage::Devicegraph]
        # @return [Y2Storage::Devicegraph]
        def devicegraph_with_fixed_encryptions(devicegraph)
          fixed_devicegraph = devicegraph.dup

          return fixed_devicegraph unless crypttab

          Y2Storage::Encryption.use_crypttab_names(fixed_devicegraph, crypttab)
          fixed_devicegraph
        end

        # Selects the crypttab contained in the same filesystem than the selected fstab
        #
        # @return [Y2Storage::Crypttab, nil] nil if the filesystem does not contain
        #   a crypttab file.
        def crypttab
          return @crypttab if @crypttab_found

          @crypttab_found = true
          @crypttab = disk_analyzer.crypttabs.find { |c| c.filesystem == selected_fstab.filesystem }
        end
      end
    end
  end
end
