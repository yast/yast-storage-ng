# Copyright (c) [2017-2020] SUSE LLC
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
require "y2partitioner/actions/controllers/base"
require "y2partitioner/blk_device_restorer"
require "y2partitioner/widgets/mkfs_optiondata"
require "y2partitioner/filesystem_role"
require "y2storage/shadower"

Yast.import "Mode"
Yast.import "Stage"

# FIXME: refactoring needed.
#
# This controller contains logic related to a blk device:
#   * Create a filesystem
#   * Remove a filesystem
#   * Edit format options
#   * Edit partition id
#
# but it also includes logic related to a filesystem:
#   * Set mount point
#   * Set mount options
#   * Edit subvolumes
#   * Set snapshots
#
# It could be splitted into different classes.

# rubocop:disable ClassLength

module Y2Partitioner
  module Actions
    module Controllers
      # This class stores information about a filesystem being created or modified
      # and takes care of updating the devicegraph when needed, so the different
      # dialogs can always work directly on a BlkFilesystem object correctly
      # placed in the devicegraph.
      class Filesystem < Base
        include Yast::Logger

        # @return [FilesystemRole] Role chosen by the user for the device
        attr_reader :role

        # @return [Boolean] Whether the user wants to encrypt the device
        attr_accessor :encrypt

        # @return [Boolean] Whether the user wants to restore the default list of subvolumes
        attr_writer :restore_btrfs_subvolumes

        # Name of the plain device
        #
        # @see #blk_device
        # @return [String]
        attr_reader :blk_device_name

        # Title to display in the dialogs during the process
        # @return [String]
        attr_reader :wizard_title

        # @param device [Y2Storage::BlkDevice, Y2Storage::Filesystems::BlkFilesystem]
        # @param wizard_title [String]
        def initialize(device, wizard_title)
          super()

          # Note that the controller could be used only for filesystem actions, see FIXME.
          if device.is?(:filesystem)
            @filesystem = device
          else
            @blk_device_name = device.name
            @encrypt = blk_device.encrypted?
            @restorer = BlkDeviceRestorer.new(blk_device)
          end

          @wizard_title = wizard_title
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

        # Whether to restore the default list of subvolumes
        #
        # Note that in some cases this implies to simply remove all the subvolumes because there is no a
        # default list of subvolumes for the current filesystem.
        #
        # @return [Boolean]
        def restore_btrfs_subvolumes?
          !!@restore_btrfs_subvolumes
        end

        # Plain block device being modified, i.e. device where the filesystem is
        # located or where it will be eventually placed/removed.
        #
        # Note this is always the plain device, no matter if it is encrypted or
        # not.
        #
        # @return [Y2Storage::BlkDevice, nil]
        def blk_device
          return nil unless blk_device_name

          Y2Storage::BlkDevice.find_by_name(working_graph, blk_device_name)
        end

        # Filesystem object being modified
        #
        # @return [Y2Storage::Filesystem::BlkFilesystem]
        def filesystem
          @filesystem || blk_device.filesystem
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
        # @return [Y2Storage::PartitionId, nil] nil if there is no block device or the
        #   block device is not a partition
        def partition_id
          return nil unless blk_device

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
          manual = current_value_for(:manual_mount_by)
          label = current_value_for(:label)

          if type.is?(:swap)
            mount_path = "swap"
          elsif mount_path == "swap"
            mount_path = nil
          end

          delete_filesystem
          create_filesystem(type, label: label)
          self.partition_id = filesystem.type.default_partition_id

          return if mount_path.nil?

          create_mount_point(mount_path, mount_by: mount_by, manual_mount_by: manual)
        end

        # Makes the changes related to the option "do not format" in the UI, which
        # implies removing any new filesystem or respecting the preexisting one.
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

          mp = filesystem.create_mount_point(path)
          options[:mount_options] ||= mp.default_mount_options
          apply_mount_point_options(options)
        end

        # Updates the current filesystem mount point
        #
        # @param path [String]
        def update_mount_point(path)
          return if mount_point.nil?
          return if mount_point.path == path

          mount_point.path = path
          options = { mount_options: mount_point.default_mount_options }
          apply_mount_point_options(options)
        end

        # Creates a mount point if the filesystem has no mount point. Otherwise, the
        # mount point is updated.
        #
        # @param path [String]
        def create_or_update_mount_point(path)
          return if filesystem.nil?

          if mount_point.nil?
            create_mount_point(path, {})
          else
            update_mount_point(path)
          end
        end

        # Removes the filesystem mount point
        def remove_mount_point
          return if mount_point.nil?

          filesystem.remove_mount_point
        end

        # Removes the current mount point (if there is one) and creates a new
        # mount point for the filesystem.
        #
        # @param path [String]
        # @param options [Hash] options for the mount point (e.g., { mount_by: :uuid })
        def restore_mount_point(path, options = {})
          return unless filesystem

          filesystem.remove_mount_point if mount_point

          return if !path || path.empty?

          filesystem.create_mount_point(path)
          apply_mount_point_options(options)
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

        # Sets quota support for the filesystem if it makes sense
        #
        # @see Y2Storage::Filesystems::Btrfs.quota=
        #
        # @param value [Boolean]
        def btrfs_quota=(value)
          return unless btrfs?

          filesystem.quota = value
        end

        # Status of the quota support for the Btrfs filesystem
        #
        # @see Y2Storage::Filesystems::Btrfs.quota?
        #
        # @return [Boolean]
        def btrfs_quota?
          return false unless btrfs?

          filesystem.quota?
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
          mount_paths = [suggested_mount_path] + all_mount_paths - mounted_paths
          mount_paths.compact.uniq
        end

        # Return a suggested mount path based on the properties of this volume
        #
        # @return [String, nil]
        def suggested_mount_path
          return "swap" if filesystem_type&.is?(:swap)
          return "/boot/efi" if partition_id&.is?(:esp)

          nil
        end

        # All paths used by the preexisting subvolumes (those that will not be
        # automatically deleted if they are shadowed)
        #
        # @return [Array<String>]
        def subvolumes_mount_paths
          subvolumes = mounted_devices.select do |dev|
            dev.is?(:btrfs_subvolume) && !dev.can_be_auto_deleted?
          end
          subvolumes.map(&:mount_path).compact.reject(&:empty?)
        end

        # Whether the filesystem is a Btrfs.
        #
        # @return [Boolean]
        def btrfs?
          return false unless filesystem

          filesystem.supports_btrfs_subvolumes?
        end

        # Whether the filesystem is a new Btrfs that was not probed
        #
        # @return [Boolean]
        def new_btrfs?
          btrfs? && new?(filesystem)
        end

        # Whether the filesystem has Btrfs subvolumes
        #
        # @return [Boolean]
        def btrfs_subvolumes?
          return false unless btrfs?

          filesystem.btrfs_subvolumes?
        end

        # Whether there is a list of default Btrfs subvolumes for the filesystem
        #
        # @return [Boolean]
        def default_btrfs_subvolumes?
          spec = filesystem.volume_specification

          return false unless spec

          spec.subvolumes.any? || !spec.btrfs_default_subvolume.empty?
        end

        # Saves the current status of the block device
        #
        # @see BlkDeviceRestorer#update_checkpoint
        def update_checkpoint
          @restorer.update_checkpoint
        end

        # Applies last changes to the filesystem at the end of the wizard
        #
        # Either the default list of subvolumes is restored or the current subvolumes are mounted at
        # their default locations.
        def finish
          if btrfs?
            # Restores the default list of subvolumes, if requested so. Otherwise, restores the default
            # mount point of the subvolumes because the mount point of the file system could be modified.
            restore_btrfs_subvolumes? ? restore_btrfs_subvolumes : restore_btrfs_subvolumes_mount_points
          end

          # Shadowing control is always performed.
          Y2Storage::Shadower.new(current_graph).refresh_shadowing
        end

        # Whether the mount path was modified
        #
        # @return [Boolean]
        def mount_path_modified?
          device = filesystem ? filesystem.blk_devices.first : blk_device
          initial_filesystem = pre_transaction_device(device)&.filesystem

          initial_filesystem&.mount_path != filesystem&.mount_path
        end

        private

        def delete_filesystem
          filesystem_parent.remove_descendants
        end

        def create_filesystem(type, label: nil)
          filesystem_parent.create_blk_filesystem(type)
          filesystem.label = label unless label.nil?
        end

        # Device containing the filesystem
        #
        # Unlike {#blk_device}, that always returns the plain device, this
        # method will return the encryption device for encrypted filesystems
        #
        # @return [Y2Storage::BlkDevice]
        def filesystem_parent
          blk_device.encrypted? ? blk_device.encryption : blk_device
        end

        def restore_filesystem
          mount_path = filesystem.mount_path
          mount_by = filesystem.mount_by
          manual = filesystem.mount_point&.manual_mount_by?

          @restorer.restore_from_system
          @encrypt = blk_device.encrypted?

          restore_mount_point(mount_path, mount_by: mount_by, manual_mount_by: manual)
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
            next if value.nil?

            if attr == :mount_by
              mount_point.assign_mount_by(value)
            else
              mount_point.send(:"#{attr}=", value)
            end
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
          when :manual_mount_by
            filesystem.mount_point&.manual_mount_by?
          when :mount_point
            filesystem.mount_path
          when :label
            # label is kept to be consistent with old partitioner (bsc#1087229)
            filesystem.label
          end
        end

        # Deletes current subvolumes, except the top level one.
        #
        # @see Y2Storage::Filesystems::Btrfs_delete_btrfs_subvolume
        def delete_btrfs_subvolumes
          filesystem.btrfs_subvolumes.map(&:path).each { |p| filesystem.delete_btrfs_subvolume(p) }

          # Auto deleted subvolumes are also discarded
          filesystem.auto_deleted_subvolumes = []
        end

        # Restores the list of default subvolumes
        #
        # The current subvolumes are deleted and the default list of subvolumes is restored, if any.
        def restore_btrfs_subvolumes
          delete_btrfs_subvolumes
          filesystem.setup_default_btrfs_subvolumes
        end

        # Restores the default mount point of the subvolumes
        def restore_btrfs_subvolumes_mount_points
          filesystem.btrfs_subvolumes.each(&:set_default_mount_point)
        end

        # Whether the filesystem has root mount point
        #
        # @return [Boolean]
        def root?
          filesystem.root?
        end

        # This implements the code that used to live in
        # Yast::Filesystems::SuggestMPoints (whatever the rationale behind those
        # mount paths was back then) with the only exception mentioned in
        # {#booting_paths}
        #
        # @return [Array<String>]
        def all_mount_paths
          @all_mount_paths ||=
            if Yast::Stage.initial
              %w[/ /home /var /opt] + booting_paths + non_system_paths
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
          devices = devices.reject { |d| d.mount_point.nil? }
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
          devices += filesystem_btrfs_subvolumes if fs.is?(:btrfs)
          devices
        end

        # Subvolumes to take into account
        #
        # Top level and default subvolumes are excluded.
        #
        # @return [Array<Y2Storage::BtrfsSubvolume>]
        def filesystem_btrfs_subvolumes
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
          spec&.btrfs_read_only?
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
