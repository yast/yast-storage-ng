# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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
require "y2storage"
require "y2partitioner/device_graphs"
require "y2partitioner/blk_device_restorer"
require "y2partitioner/widgets/mkfs_optiondata"
require "y2partitioner/filesystem_role"
require "y2storage/filesystems/btrfs"
require "y2storage/subvol_specification"

Yast.import "Mode"
Yast.import "Stage"

# TODO: This class is too long. Please, consider refactoring.
# The code could be splitted in two kind of groups: one for actions
# related to mount point options and another group for actions related
# to filesystem options.

# rubocop:disable ClassLength

module Y2Partitioner
  module Actions
    module Controllers
      # This class stores information about a filesystem being created or modified
      # and takes care of updating the devicegraph when needed, so the different
      # dialogs can always work directly on a BlkFilesystem object correctly
      # placed in the devicegraph.
      class Filesystem
        include Yast::Logger

        # @return [FilesystemRole] Role chosen by the user for the device
        attr_reader :role

        # @return [Boolean] Whether the user wants to encrypt the device
        attr_accessor :encrypt

        # @return [String] Password for the encryption device
        attr_accessor :encrypt_password

        # Name of the plain device
        #
        # @see #blk_device
        # @return [String]
        attr_reader :blk_device_name

        # Title to display in the dialogs during the process
        # @return [String]
        attr_reader :wizard_title

        # @param device [Y2Storage::BlkDevice] see {#blk_device)
        # @param wizard_title [String]
        def initialize(device, wizard_title)
          @blk_device_name = device.name
          @encrypt = blk_device.encrypted?
          @wizard_title = wizard_title
          @restorer = BlkDeviceRestorer.new(blk_device)
        end

        # Sets the id of the role to be used in subsequent operations
        #
        # @see #role
        #
        # @param id [Symbol]
        def role_id=(id)
          @role = FilesystemRole.find(id)
        end

        # Id of the current chosen role, nil if no role is selected
        #
        # @see #role
        #
        # @return [Symbol, nil]
        def role_id
          @role ? role.id : nil
        end

        # Plain block device being modified, i.e. device where the filesystem is
        # located or where it will be eventually placed/removed.
        #
        # Note this is always the plain device, no matter if it is encrypted or
        # not.
        #
        # @return [Y2Storage::BlkDevice]
        def blk_device
          Y2Storage::BlkDevice.find_by_name(working_graph, blk_device_name)
        end

        # Filesystem object being modified
        #
        # @return [Y2Storage::BlkFilesystem]
        def filesystem
          blk_device.filesystem
        end

        # Type of the current filesystem
        #
        # @return [Y2Storage::Filesystems::Type, nil] nil if there is no filesystem
        def filesystem_type
          filesystem ? filesystem.type : nil
        end

        # Whether the block device will be formatted, i.e. a new filesystem will
        # be created when commiting the devicegraph.
        #
        # @return [Boolean]
        def to_be_formatted?
          return false if filesystem.nil?
          new?(filesystem)
        end

        # Whether a new encryption device will be created for the block device
        #
        # @return [Boolean]
        def to_be_encrypted?
          return false unless can_change_encrypt?
          encrypt && !blk_device.encrypted?
        end

        # Mount point of the current filesystem
        #
        # @return [MountPoint, nil] nil if there is no filesystem
        def mount_point
          return nil if filesystem.nil?
          filesystem.mount_point
        end

        # Path of the mount point for the current filesystem
        #
        # @return [String, nil] nil if the filesystem has no mount point
        def mount_path
          return nil if mount_point.nil?
          mount_point.path
        end

        # Partition id of the block device if it is a partition
        #
        # @return [Y2Storage::PartitionId, nil] nil if {#blk_device} is not a
        #   partition
        def partition_id
          blk_device.is?(:partition) ? blk_device.id : nil
        end

        # Modifies the block filesystem based on {#role}
        #
        # This creates a new filesystem object on top of the block device if
        # needed, modifies the partition id when it makes sense, etc.
        def apply_role
          delete_filesystem
          @encrypt = false

          return if role.nil?
          self.partition_id = role.partition_id

          fs_type = role.filesystem_type
          mount_path = role.mount_path(mount_paths)
          return if fs_type.nil?

          create_filesystem(fs_type)
          create_mount_point(mount_path) if mount_path
          filesystem.configure_snapper = role.snapper?(blk_device) if snapshots_supported?
        end

        # Creates a new filesystem on top of the block device, removing the
        # previous one if any, as a result of the user choosing the option in the
        # UI to format the device.
        #
        # Some information from the previous filesystem (like the mount point or
        # the label) is kept in the new filesystem if it makes sense.
        #
        # @param type [Symbol] e.g., :ext4, :btrfs, :xfs
        def new_filesystem(type)
          # Make sure type has the correct... well, type :-)
          type = Y2Storage::Filesystems::Type.new(type)

          # It's kind of expected that these attributes are preserved when
          # changing the filesystem type, with the exceptions below
          mount_path = current_value_for(:mount_point)
          mount_by = current_value_for(:mount_by)
          label = current_value_for(:label)

          if type.is?(:swap)
            mount_path = "swap"
          elsif mount_path == "swap"
            mount_path = nil
          end

          delete_filesystem
          create_filesystem(type, label: label)
          self.partition_id = filesystem.type.default_partition_id

          create_mount_point(mount_path, mount_by: mount_by) unless mount_path.nil?
        end

        # Makes the changes related to the option "do not format" in the UI, which
        # implies removing any new filesystem or respecting the preexisting one.
        #
        # @note With the current implementation there is a corner case that
        # doesn't work like the traditional expert partitioner. If a partition
        # preexisting in the disk is edited (e.g. replacing the filesystem with a
        # new one) and then we the user tries to edit it again, "do not format"
        # will actually mean leaving the partition unformatted, not respecting the
        # filesystem on the system.
        def dont_format
          return if filesystem.nil?
          return unless new?(filesystem)

          if @restorer.can_restore_from_system?
            restore_filesystem
          else
            delete_filesystem
          end
        end

        # Sets the partition id of the block device if it makes sense
        def partition_id=(partition_id)
          return unless partition_id_supported?
          return if partition_id.nil?

          # Make sure partition_id has the correct type
          partition_id = Y2Storage::PartitionId.new(partition_id)
          blk_device.adapted_id = partition_id
        end

        # Creates a mount point for the current filesystem
        #
        # @note The new mount point is created with default mount options if no mount
        #   options are given (see {Y2Storage::Filesystems::Type#default_mount_options}).
        #
        #   Take into account that modifying the mount point can have side effects
        #   if the filesystem doesn't exist yet, like changing the list of
        #   subvolumes if the new or old mount point is "/".
        #
        # @param path [String]
        # @param options [Hash] options for the mount point (e.g., { mount_by: :uuid } )
        def create_mount_point(path, options = {})
          # The mount point cannot be created if there is no filesystem
          return if filesystem.nil?
          # The mount point is not created if there is already a mount point
          return unless mount_point.nil?

          options[:mount_options] ||= filesystem.type.default_mount_options(path)

          before_change_mount_point
          filesystem.create_mount_point(path)
          apply_mount_point_options(options)
          after_change_mount_point
        end

        # Updates the current filesystem mount point
        #
        # @param path [String]
        # @param options [Hash] options for the mount point (e.g., { mount_by: :uuid })
        def update_mount_point(path, options = {})
          return if mount_point.nil?
          return if mount_point.path == path && (options.nil? || options.empty?)

          before_change_mount_point
          mount_point.path = path
          apply_mount_point_options(options)
          after_change_mount_point
        end

        # Creates a mount point if the filesystem has no mount point. Otherwise, the
        # mount point is updated.
        #
        # @param path [String]
        # @param options [Hash] options for the mount point (e.g., { mount_by: :uuid })
        def create_or_update_mount_point(path, options = {})
          return if filesystem.nil?

          if mount_point.nil?
            create_mount_point(path, options)
          else
            update_mount_point(path, options)
          end
        end

        # Removes the filesystem mount point
        def remove_mount_point
          return if mount_point.nil?

          before_change_mount_point
          filesystem.remove_mount_point
          after_change_mount_point
        end

        # Removes the current mount point (if there is one) and creates a new
        # mount point for the filesystem.
        #
        # @param path [String]
        # @param options [Hash] options for the mount point (e.g., { mount_by: :uuid })
        def restore_mount_point(path, options = {})
          if filesystem.nil?
            # No chance to restore the mount point, let's unshadow its
            # potentially shadowed subvolumes
            Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing(working_graph)
            return
          end

          before_change_mount_point

          filesystem.remove_mount_point if mount_point

          if path && !path.empty?
            filesystem.create_mount_point(path)
            apply_mount_point_options(options)
          end

          after_change_mount_point
        end

        # Applies last changes to the block device at the end of the wizard, which
        # mainly means encrypting the device or removing the encryption layer for
        # non preexisting devices.
        def finish
          return unless can_change_encrypt?

          if to_be_encrypted?
            blk_device.encrypt(password: encrypt_password)
          elsif blk_device.encrypted? && !encrypt
            blk_device.remove_encryption
          end
        ensure
          @restorer.update_checkpoint
        end

        # Whether is possible to define the generic format options for the current
        # filesystem
        #
        # @return [Boolean]
        def format_options_supported?
          to_be_formatted? && !Widgets::MkfsOptiondata.options_for(filesystem).empty?
        end

        # Whether is possible to set the snapshots configuration for the current
        # filesystem
        #
        # @see Y2Storage::Filesystems::Btrfs.configure_snapper
        #
        # @return [Boolean]
        def snapshots_supported?
          return false unless Yast::Mode.installation
          return false unless to_be_formatted?
          filesystem.can_configure_snapper?
        end

        # Whether is possible to set the partition id for the block device
        #
        # @return [Boolean]
        def partition_id_supported?
          blk_device.is?(:partition)
        end

        # Sets configure_snapper for the filesystem if it makes sense
        #
        # @see Y2Storage::Filesystems::Btrfs.configure_snapper=
        #
        # @param value [Boolean]
        def configure_snapper=(value)
          return if filesystem.nil? || !filesystem.respond_to?(:configure_snapper)
          filesystem.configure_snapper = value
        end

        # Status of the snapshots configuration for the filesystem
        #
        # @see Y2Storage::Filesystems::Btrfs.configure_snapper
        #
        # @return [Boolean]
        def configure_snapper
          return false if filesystem.nil? || !filesystem.respond_to?(:configure_snapper)
          filesystem.configure_snapper
        end

        # Paths that are mounted in the current device graph, excluding
        # subvolumes
        #
        # @return [Array<String>]
        def mounted_paths
          devices = mounted_devices.reject { |d| d.is?(:btrfs_subvolume) }
          devices.map(&:mount_path)
        end

        # Sorted list of the default mount paths to offer to the user
        #
        # @return [Array<String>]
        def mount_paths
          mount_paths = all_mount_paths - mounted_paths
          mount_paths.unshift("swap") if filesystem && filesystem.type.is?(:swap)
          mount_paths
        end

        # All paths used by the preexisting subvolumes (those that will not be
        # automatically deleted if they are shadowed)
        #
        # @return [Array<String>]
        def subvolumes_mount_paths
          subvolumes = mounted_devices.select do |dev|
            dev.is?(:btrfs_subvolume) && !dev.can_be_auto_deleted?
          end
          subvolumes.map(&:mount_path).compact.select { |m| !m.empty? }
        end

        # Check if the filesystem is a btrfs.
        #
        # @return [Boolean]
        def btrfs?
          filesystem.supports_btrfs_subvolumes?
        end

      private

        def working_graph
          DeviceGraphs.instance.current
        end

        def system_graph
          DeviceGraphs.instance.system
        end

        def can_change_encrypt?
          filesystem.nil? || new?(filesystem)
        end

        def new?(device)
          !device.exists_in_devicegraph?(system_graph)
        end

        def delete_filesystem
          blk_device.remove_descendants
          # Shadowing control of btrfs subvolumes might be needed if the deleted
          # filesystem had mount point
          Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing(working_graph)
        end

        def create_filesystem(type, label: nil)
          blk_device.create_blk_filesystem(type)
          filesystem.label = label unless label.nil?
        end

        def restore_filesystem
          mount_path = filesystem.mount_path
          mount_by = filesystem.mount_by

          @restorer.restore_from_system
          @encrypt = blk_device.encrypted?

          restore_mount_point(mount_path, mount_by: mount_by)
          blk_device.update_etc_status
        end

        # Sets options to the current mount point
        #
        # @param options [Hash] options for the mount point, e.g.,
        #   { mount_by: :uuid, mount_options: ["ro"] }
        def apply_mount_point_options(options)
          return if mount_point.nil?

          # FIXME: Simplify this. This generic anonymous hash might contain
          # anything; it's very similar to the old target map that left
          # everybody guessing what it contained.  If we need a helper class to
          # store some old values for the mount point object, let's create
          # one. But probably it's just those two fields mentioned above that
          # need to be taken into account, and for this that "options" hash is
          # not only complete overkill, it also wraps the wrapper class into
          # another layer of indirection.
          # See RFC 1925 section 6a (and section 3).
          options.each_pair do |attr, value|
            mount_point.send(:"#{attr}=", value) unless value.nil?
          end

          # Special handling for some mount paths ("/", "/boot/*")
          opt = options[:mount_options] || []
          mount_point.mount_options = add_special_mount_options_for(mount_point.path, opt)
        end

        def current_value_for(attribute)
          return nil if filesystem.nil?

          case attribute
          when :mount_by
            filesystem.mount_by
          when :mount_point
            filesystem.mount_path
          when :label
            # Copying the label from the filesystem in the disk looks unexpected
            new?(filesystem) ? filesystem.label : nil
          end
        end

        def before_change_mount_point
          # When the filesystem is btrfs, the not probed subvolumes are deleted.
          delete_not_probed_subvolumes if btrfs?
        end

        def after_change_mount_point
          if btrfs? && mount_point
            filesystem.setup_default_btrfs_subvolumes
            update_mount_points
          end
          # Shadowing control of btrfs subvolumes is always performed.
          Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing(working_graph)
        end

        # Deletes not probed subvolumes
        def delete_not_probed_subvolumes
          loop do
            subvolume = find_not_probed_subvolume
            return if subvolume.nil?
            filesystem.delete_btrfs_subvolume(subvolume.path)
          end
        end

        # Finds first not probed subvolume
        #
        # @note Top level subvolume is not taken into account.
        #
        # @return [Y2Storage::BtrfsSubvolume, nil]
        def find_not_probed_subvolume
          filesystem.btrfs_subvolumes.detect do |subvolume|
            !subvolume.top_level? && !subvolume.exists_in_devicegraph?(system_graph)
          end
        end

        # Updates subvolumes mount point
        #
        # @note Top level and default subvolumes are not taken into account (see {#subvolumes}).
        def update_mount_points
          subvolumes.each do |subvolume|
            new_mount_point = filesystem.btrfs_subvolume_mount_point(subvolume.path)
            if new_mount_point.nil?
              subvolume.remove_mount_point if subvolume.mount_point
            else
              subvolume.mount_path = new_mount_point
            end
          end
        end

        # Btrfs subvolumes without top level and default ones
        def subvolumes
          filesystem.btrfs_subvolumes.select do |subvolume|
            !subvolume.top_level? && !subvolume.default_btrfs_subvolume?
          end
        end

        def root?
          filesystem.root?
        end

        # This implements the code that used to live in
        # Yast::Filesystems::SuggestMPoints (whatever the rationle behind those
        # mount paths was back then) with the only exception mentioned in
        # {#booting_paths}
        #
        # @return [Array<String>]
        def all_mount_paths
          @all_mount_paths ||=
            if Yast::Stage.initial
              %w(/ /home /var /opt) + booting_paths + non_system_paths
            else
              ["/home"] + non_system_paths
            end
        end

        # Mount paths suggested for the boot-related partitions.
        #
        # This is somehow similar to the old Yast::Partitions::BootMount but
        # with an important difference - it returns a list instead of a single
        # path. yast-storage used to consider there was only a single "boot"
        # partition, with /boot/efi and /boot/zipl being considered some kind
        # of alternative to /boot.
        #
        # @see #mount_paths
        #
        # @return [Array<String>]
        def booting_paths
          paths = ["/boot"]
          paths << "/boot/efi" if arch.efiboot?
          paths << "/boot/zipl" if arch.s390?
          paths
        end

        # @see #mount_paths
        #
        # @return [Array<String>]
        def non_system_paths
          ["/srv", "/tmp", "/usr/local"]
        end

        # Devices that are currently mounted in the system, except those
        # associated to the current filesystem.
        #
        # @see #filesystem_devices
        #
        # @return [Array<Y2Storage::Mountable>]
        def mounted_devices
          fs_sids = filesystem_devices.map(&:sid)
          devices = Y2Storage::Mountable.all(working_graph)
          devices = devices.select { |d| !d.mount_point.nil? }
          devices.reject { |d| fs_sids.include?(d.sid) }
        end

        # Returns the devices associated to the current filesystem.
        #
        # @note The devices associated to the filesystem are the filesystem itself and its
        #   subvolumes in case of a btrfs filesystem.
        #
        # @return [Array<Y2Storage::Mountable>]
        def filesystem_devices
          fs = filesystem
          return [] if fs.nil?

          devices = [fs]
          devices += filesystem_subvolumes if fs.is?(:btrfs)
          devices
        end

        # Subvolumes to take into account
        # @return [Array[Y2Storage::BtrfsSubvolume]]
        def filesystem_subvolumes
          filesystem.btrfs_subvolumes.select { |s| !s.top_level? && !s.default_btrfs_subvolume? }
        end

        # @return [Storage::Arch]
        def arch
          Y2Storage::StorageManager.instance.arch
        end

        # Determines whether a file system should be read-only by default
        #
        # @param path [String] Mount point path
        # @return [Boolean]
        def read_only?(path)
          spec = Y2Storage::VolumeSpecification.for(path)
          spec && spec.btrfs_read_only?
        end

        # Adds special mount options for a given path
        #
        # @param path          [String] Mount point path
        # @param mount_options [Array<String>] Original set of options
        # @return [Array<String>] Mount options including special ones
        def add_special_mount_options_for(path, mount_options)
          opt = filesystem.type.special_path_fstab_options(mount_options, path)
          opt.push("ro") if read_only?(path)
          opt
        end
      end
    end
  end
end

# rubocop:enable ClassLength
