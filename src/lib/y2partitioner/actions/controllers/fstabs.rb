# Copyright (c) [2018-2019] SUSE LLC
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
require "y2partitioner/filesystems"
require "y2partitioner/actions/controllers/base"
require "y2storage"

Yast.import "Arch"

module Y2Partitioner
  module Actions
    module Controllers
      # This class stores information about the fstab files read from all
      # the filesystem in the system. It also saves information about the
      # selected fstab to be used to import mount points.
      class Fstabs < Base
        include Yast::I18n

        # @return [Y2Storage::Fstab] fstab file selected to import mount points
        attr_reader :selected_fstab

        # @return [Boolean] whether the system volumes must be formatted
        #
        # @note A volume is considered as "system volume" when it is mounted in certain
        #   specific mount point like /, /usr, etc. See {#system_mount_points}.
        attr_accessor :format_system_volumes
        alias_method :format_system_volumes?, :format_system_volumes

        # Constructor
        def initialize
          super()
          textdomain "storage"
        end

        # All fstab files found in the system
        #
        # @return [Array<Y2Storage::Fstab>]
        def fstabs
          disk_analyzer.fstabs
        end

        # Sets the selected fstab
        #
        # Note that the system graph with crypttab names need to be reset after selecting a new fstab.
        #
        # @param [Y2Storage::Fstab] new_fstab
        def selected_fstab=(new_fstab)
          reset_system_graph_with_crypttab_names

          @selected_fstab = new_fstab
        end

        # Selects the previous fstab
        #
        # The current selected fstab does not change if it already is the first one.
        #
        # @return [Y2Storage::Fstab]
        def select_prev_fstab
          current_index = fstabs.index(selected_fstab)
          prev_index = [0, current_index - 1].max

          self.selected_fstab = fstabs.at(prev_index)
        end

        # Selects the next fstab
        #
        # The current selected fstab does not change if it already is the last one.
        #
        # @return [Y2Storage::Fstab]
        def select_next_fstab
          current_index = fstabs.index(selected_fstab)
          next_index = [fstabs.size - 1, current_index + 1].min

          self.selected_fstab = fstabs.at(next_index)
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
          device = entry.device(system_graph_with_crypttab_names)

          return false unless device

          return true unless must_be_formatted?(device, entry.mount_point)

          usable_fs_type?(entry) && can_be_formatted?(device)
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
          @system_mount_points << "/boot/zipl" if Yast::Arch.s390
          @system_mount_points
        end

        # Whether a fstab entry has an usable filesystem type
        #
        # A filesystem type is usable when it is known and supported.
        #
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        # @return [Boolean]
        def usable_fs_type?(entry)
          known_fs_type?(entry) && supported_fs_type?(entry)
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

        # Whether a fstab entry has a filesystem type supported by the Partitioner
        #
        # Only some filesystem types are supported by Partitioner, see {Filesystems.all}.
        #
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        # @return [Boolean]
        def supported_fs_type?(entry)
          Filesystems.supported?(entry.fs_type)
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

        # Resets the system graph containing crypttab names
        def reset_system_graph_with_crypttab_names
          @system_graph_with_crypttab_names = nil
        end

        # Imports the mount point of a fstab entry
        #
        # When the device needs to be formatted (see {#must_be_formatted?}), the filesystem type
        # indicated in the entry is used. In case the device is not a block device (e.g., NFS),
        # the device is not formatted and only the mount point, mount by method and mount options
        # are assigned.
        #
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        def import_mount_point(entry)
          device = entry.device(system_graph_with_crypttab_names)
          return unless device

          device = device_from_current_graph(device)

          if must_be_formatted?(device, entry.mount_point)
            filesystem = format_device(device, entry)
            create_mount_point(filesystem, entry)
            setup_blk_filesystem(filesystem)
          else
            filesystem = device.is?(:filesystem) ? device : device.filesystem
            create_mount_point(filesystem, entry)
          end
        end

        # Device version from the current devicegraph
        #
        # @param device [Y2Storage::Device]
        # @return [Y2Storage::Device]
        def device_from_current_graph(device)
          if missing_swap_encryption?(device)
            copy_swap_encryption(device)
          else
            current_graph.find_device(device.sid)
          end
        end

        # Copies a plain encryption for swap into the current devicegraph
        #
        # @param device [Y2Storage::Encryption]
        # @return [Y2Storage::Encryption]
        def copy_swap_encryption(device)
          blk_device = device_from_current_graph(device.blk_device)
          blk_device.remove_descendants

          device.copy_to(current_graph)
        end

        # Formats the device indicated in the fstab entry
        #
        # The filesystem label is preserved.
        #
        # @param device [Y2Storage::BlkDevice]
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        #
        # @return [Y2Storage::Filesystems::Base]
        def format_device(device, entry)
          label = filesystem_label(device)

          device.delete_filesystem

          filesystem = device.create_filesystem(entry.fs_type)
          filesystem.label = label if label

          filesystem
        end

        # Label of the current filesystem (if any)
        #
        # @param device [Y2Storage::BlkDevice]
        # @return [String, nil] nil if the device is not formatted
        def filesystem_label(device)
          return nil unless device.formatted?

          device.filesystem.label
        end

        # Creates the #{Y2Storage::MountPoint} object based on the imported
        # fstab entry.
        #
        # @param filesystem [Y2Storage::Filesystems::Base]
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        def create_mount_point(filesystem, entry)
          filesystem.mount_path = entry.mount_point
          filesystem.mount_point.mount_by = entry.mount_by if entry.mount_by
          filesystem.mount_point.mount_options = entry.mount_options if entry.mount_options.any?
        end

        # Performs any additional final step needed for the new block filesystem (Btrfs stuff, so far)
        #
        # @param filesystem [Y2Storage::Filesystems::BlkFilesystem]
        def setup_blk_filesystem(filesystem)
          add_filesystem_devices(filesystem)

          if filesystem.can_configure_snapper?
            filesystem.configure_snapper = filesystem.default_configure_snapper?
          end

          filesystem.setup_default_btrfs_subvolumes if filesystem.supports_btrfs_subvolumes?
        end

        # Adds missing devices to the filesystem when the original filesystem was a multi-device Btrfs
        #
        # @param filesystem [Y2Storage::Filesystems::BlkFilesystem]
        def add_filesystem_devices(filesystem)
          original_filesystem = original_filesystem(filesystem)

          return unless original_filesystem&.multidevice?

          devices = original_filesystem.blk_devices.map { |d| current_graph.find_device(d.sid) }.compact

          devices.each { |d| add_filesystem_device(filesystem, d) }
        end

        # Adds a device to the filesystem
        #
        # @param filesystem [Y2Storage::Filesystems::BlkFilesystem]
        # @param device [Y2Storage::BlkDevice]
        def add_filesystem_device(filesystem, device)
          return if filesystem.blk_devices.map(&:sid).include?(device.sid)

          filesystem.add_device(device)
        end

        # Original version of the filesystem in the system graph
        #
        # @param filesystem [Y2Storage::Filesystems::BlkFilesystem]
        # @return [Y2Storage::Filesystems::BlkFilesystem, nil] nil if the filesystem cannot be found in
        #   system graph.
        def original_filesystem(filesystem)
          original_device = system_device(filesystem.blk_devices.first)

          return nil unless original_device&.formatted?

          original_device.filesystem
        end

        # System graph with information about crypttab names indicated in the selected crypttab file
        #
        # When the device name in a fstab entry corresponds to a encryption device, the device could be
        # not found by its fstab name. In general, encryptions might be probed with a different name, so
        # before searching for the device, the encryption names from the crypttab file are saved into the
        # proper encryption device. Also note that a random encryption layer can be created when a
        # crypttab entry points to a swap device encrypted with random password. All these changes are
        # made in a temporary devicegraph, so the original system graph is never altered.
        #
        # @see #add_crypttab_names_to
        #
        # @return [Y2Storage::Devicegraph]
        def system_graph_with_crypttab_names
          @system_graph_with_crypttab_names ||= add_crypttab_names_to(system_graph)
        end

        # Duplicates the given devicegraph and saves the encryption names from the crypttab file
        #
        # @see #crypttab
        #
        # @param devicegraph [Y2Storage::Devicegraph]
        # @return [Y2Storage::Devicegraph]
        def add_crypttab_names_to(devicegraph)
          fixed_devicegraph = devicegraph.dup

          return fixed_devicegraph unless crypttab

          crypttab.save_encryption_names(fixed_devicegraph)
          fixed_devicegraph
        end

        # Selects the crypttab contained in the same filesystem than the selected fstab
        #
        # @return [Y2Storage::Crypttab, nil] nil if the filesystem does not contain a crypttab file.
        def crypttab
          disk_analyzer.crypttabs.find { |c| c.filesystem == selected_fstab.filesystem }
        end

        # Whether the given device represents a not probed encryption generated by a swap encryption
        # method
        #
        # Note that no headers are written into the device when using plain encryption (which is the
        # underlying technology used for randomly encrypted swaps). For this reason, plain encryption
        # devices are only probed for the root filesystem by parsing its crypttab file.
        #
        # A plain encryption device might be created when searching for a device from a fstab entry, see
        # {Y2Storage::Crypttab.save_encryption_names}.
        #
        # @param device [Y2Storage::Device]
        # @return [Boolean]
        def missing_swap_encryption?(device)
          missing_device?(device) && swap_encryption?(device)
        end

        # Whether the given device is missing in the probed devicegraph
        #
        # @param device [Y2Storage::Device]
        # @return [Boolean]
        def missing_device?(device)
          !device.exists_in_devicegraph?(system_graph)
        end

        # Whether the given device is an encryption generated by a swap encryption method
        #
        # @param device [Y2Storage::Encryption]
        # @return [Boolean]
        def swap_encryption?(device)
          device.is?(:encryption) && device.method.only_for_swap?
        end
      end
    end
  end
end
