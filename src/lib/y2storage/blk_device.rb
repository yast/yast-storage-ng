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

require "y2storage/storage_class_wrapper"
require "y2storage/device"
require "y2storage/hwinfo_reader"
require "y2storage/comparable_by_name"
require "y2storage/match_volume_spec"

module Y2Storage
  # Base class for most devices having a device name, udev path and udev ids.
  #
  # This is a wrapper for Storage::BlkDevice
  class BlkDevice < Device
    wrap_class Storage::BlkDevice,
      downcast_to: ["Partitionable", "Partition", "Encryption", "LvmLv", "StrayBlkDevice"]

    include ComparableByName
    include MatchVolumeSpec

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<BlkDevice>] all the block devices in the given devicegraph
    storage_class_forward :all, as: "BlkDevice"

    # @!method self.find_by_name(devicegraph, name)
    #   @param devicegraph [Devicegraph]
    #   @param name [String] kernel-style device name (e.g. "/dev/sda1")
    #   @return [BlkDevice] nil if there is no such block device
    storage_class_forward :find_by_name, as: "BlkDevice"

    # @!method self.find_by_any_name(devicegraph, name)
    #   Finds a block device by any name including any symbolic link in
    #   the /dev directory.
    #
    #   @note: Might require a system lookup and is therefore slow.
    #   @note: According to libstorage-ng, it only works on the probed
    #   devicegraph. Likely, even that is not reliable after a commit.
    #
    #   @raise [Storage::Exception] if the devicegraph provided as first
    #     argument is not the probed one
    #
    #   @param devicegraph [Devicegraph] the probed devicegraph
    #   @param name [String] any kind of device name
    #   @return [BlkDevice] nil if there is no such block device
    storage_class_forward :find_by_any_name, as: "BlkDevice"

    # @!attribute name
    #   @return [String] kernel-style device name
    #     (e.g. "/dev/sda2" or "/dev/vg_name/lv_name")
    storage_forward :name
    storage_forward :name=

    # @!attribute region
    #   @return [Region]
    storage_forward :region, as: "Region"
    storage_forward :region=

    # @!attribute size
    #   @return [DiskSize]
    storage_forward :size, as: "DiskSize"
    storage_forward :size=

    # @!method active?
    #   Checks whether the device is active
    #
    #   Some devices must be activated to access to them. For example: Multipath, LVM VGs,
    #   Encryption devices or RAIDs. During the probing phase, those devices are activated,
    #   asking to the user when it is required (e.g., to ask for the encryption password).
    #   This method indicates whether the device was actually activated during the probing.
    #
    #   @return [Boolean]
    storage_forward :active?

    # @!method sysfs_name
    #   @return [String] e.g. "sda2" or "dm-1"
    storage_forward :sysfs_name

    # @!method sysfs_path
    #   e.g. "/devices/pci00:0/00:0:1f.2/ata1/host0/target0:0:0/0:0:0:0/block/sda/sda2"
    #   or "/devices/virtual/block/dm-1"
    #   @return [String]
    storage_forward :sysfs_path

    # @!method usable_as_blk_device?
    #   Checks whether the device is in general usable as a block device.
    #
    #   This is not the case for some DASDs. For more information, see
    #   https://github.com/openSUSE/libstorage-ng/blob/master/doc/dasd.md
    #
    #   This does not consider if the block device is already in use.
    #
    #   @return [Boolean]
    storage_forward :usable_as_blk_device?

    # Position of the first block of the region
    #
    # @return [Integer]
    def start
      region.start
    end

    # Position of the last block of the region
    #
    # @raise [Storage::Exception] if the region is empty
    #
    # @return [Integer]
    def end
      region.end
    end

    # Size of a single block
    #
    # @return [DiskSize]
    def block_size
      region.block_size
    end

    # Full paths of all the udev by-* links. an empty array for devices
    # not handled by udev.
    #
    # Take into account that libstorage-ng intentionally filter outs many udev
    # paths and ids, so the list is expected to be incomplete. If you need to
    # lookup a device by its udev name, check {.find_by_all_names}.
    #
    # @see #udev_full_paths
    # @see #udev_full_ids
    # @see #udev_full_uuid
    # @see #udev_full_label
    # @return [Array<String>]
    def udev_full_all
      res = udev_full_paths.concat(udev_full_ids)
      res << udev_full_uuid << udev_full_label

      res.compact
    end

    # @!method udev_paths
    #   Names of all the udev by-path links. An empty array for devices
    #   not handled by udev.
    #   E.g. ["pci-0000:00:1f.2-ata-1-part2"]
    #
    #   Take into account that libstorage-ng intentionally filter outs many udev
    #   paths. Check the documentation of {#udev_full_all} for more information.
    #
    #   @see #udev_full_paths
    #   @return [Array<String>]
    storage_forward :udev_paths

    # Full paths of all the udev by-path links. An empty array for devices
    # not handled by udev.
    # E.g. ["/dev/disk/by-path/pci-0000:00:1f.2-ata-1-part2"]
    #
    # Take into account that libstorage-ng intentionally filter outs many udev
    # paths. Check the documentation of {#udev_full_all} for more information.
    #
    # @see #udev_paths
    # @return [Array<String>]
    def udev_full_paths
      udev_paths.map { |path| File.join("/dev", "disk", "by-path", path) }
    end

    # @!method udev_ids
    #   Names of all the udev by-id links. An empty array for devices
    #   not handled by udev.
    #   E.g. ["scsi-350014ee658db9ee6"]
    #
    #   Take into account that libstorage-ng intentionally filter outs many udev
    #   ids. Check the documentation of {#udev_full_all} for more information.
    #
    #   @see #udev_full_ids
    #   @return [Array<String]
    storage_forward :udev_ids

    # Full paths of all the udev by-id links. An empty array for devices
    # not handled by udev.
    # E.g. ["/dev/disk/by-id/scsi-350014ee658db9ee6"]
    #
    # Take into account that libstorage-ng intentionally filter outs many udev
    # ids. Check the documentation of {#udev_full_all} for more information.
    #
    # @see #udev_ids
    # @return [Array<String>]
    def udev_full_ids
      udev_ids.map { |id| File.join("/dev", "disk", "by-id", id) }
    end

    # @!attribute dm_table_name
    #   Device-mapper table name. Empty if this is not a device-mapper device.
    #   @return [String]
    storage_forward :dm_table_name
    storage_forward :dm_table_name=

    # @!method create_blk_filesystem(fs_type)
    #   Creates a new filesystem object on top of the device in order to format it.
    #
    #   @param fs_type [Filesystems::Type]
    #   @return [Filesystems::BlkFilesystem]
    storage_forward :create_blk_filesystem, as: "Filesystems::BlkFilesystem", raise_errors: true
    alias_method :create_filesystem, :create_blk_filesystem

    # @!method create_bcache(name)
    #   Creates backing device build on current block device with given name.
    #
    #   If the blk device has children, the children will become children of
    #   the bcache device.
    #
    #   @param name [String] name of bcache device
    #   @return [Bcache]
    storage_forward :create_bcache, as: "Bcache", raise_errors: true

    # @!method create_bcache_cset
    #   Creates caching set build on current block device.
    #
    #   Blk device have to not contain any children.
    #
    #   @raise [Storage::WrongNumberOfChildren] if there is any children
    #   @return [BcacheCset]
    storage_forward :create_bcache_cset, as: "Bcache", raise_errors: true

    # @!method create_encryption(dm_name)
    #   Creates a new encryption object on top of the device.
    #
    #   If the blk device has children, the children will become children of
    #   the encryption device.
    #
    #   @note: NEVER use this if any child of the block device already exists
    #   in the real system. It will fail during commit.
    #
    #   @param dm_name [String] see #dm_table_name
    #   @return [Encryption]
    storage_forward :create_encryption, as: "Encryption", raise_errors: true

    # @!method remove_encryption
    #   Removes an encryption device on the block device.
    #
    #   If the encryption device has children, the children will become direct
    #   children of the block device.
    #
    #   @note: NEVER use this if any child of the encryption device already
    #   exists in the real system. It will fail during commit.
    #
    #   @raise [Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType] if
    #     the device is not encrypted.
    storage_forward :remove_encryption, raise_errors: true

    # @!method direct_blk_filesystem
    #   Filesystem directly placed in the device (no encryption or any other
    #   layer in between)
    #
    #   This is a wrapper for Storage::BlkDevice#blk_filesystem
    #
    #   @return [Filesystems::BlkFilesystem] nil if the raw device is not
    #     formatted
    storage_forward :direct_blk_filesystem,
      to: :blk_filesystem, as: "Filesystems::BlkFilesystem", check_with: :has_blk_filesystem

    # @!method encryption
    #   Encryption device directly placed on top of the device
    #
    #   @return [Encryption] nil if the device is not encrypted
    storage_forward :encryption, as: "Encryption", check_with: :has_encryption

    # Checks whether the device is encrypted
    #
    # @return [boolean]
    def encrypted?
      !encryption.nil?
    end

    # Creates a new encryption object on top of the device using
    # {#create_encryption}
    #
    # If the new DeviceMapper name is not passed, this method will generate a
    # default name that will be updated by subsequent calls to
    # {Encryption#update_dm_names}.
    #
    # @param dm_name [String, nil] DeviceMapper table name of the new device
    # @param password [String, nil] password of the new device
    # @return [Encryption]
    def encrypt(dm_name: nil, password: nil)
      enc = create_encryption(dm_name || "")
      enc.auto_dm_name = !dm_name
      enc.password = password if password
      Encryption.update_dm_names(devicegraph)
      enc
    end

    # Filesystem placed in the device, either directly or through an encryption
    # layer.
    #
    # @return [Filesystems::BlkFilesystem] nil if neither the raw device or its
    #   encrypted version are formatted
    def blk_filesystem
      encrypted? ? encryption.direct_blk_filesystem : direct_blk_filesystem
    end

    alias_method :filesystem, :blk_filesystem

    # Checks whether the device is formatted
    #
    # @return [Boolean]
    def formatted?
      !filesystem.nil?
    end

    # Checks whether the device is formatted with specific filesystem format
    #
    # @param fs_types [Array<Symbol>] :ext2, :btrfs, :swap, etc (see {Filesystems::Type})
    # @return [Boolean] true if formatted with one of the given formats; false otherwise.
    def formatted_as?(*fs_types)
      formatted? && filesystem.type.is?(*fs_types)
    end

    # Removes the filesystem when the device is formatted
    def delete_filesystem
      return if filesystem.nil?
      remove_descendants
    end

    # Mount point of the filesystem
    #
    # @return [Y2Storage::MountPoint, nil] nil if the device is not formatted or its
    #   filesystem has no mount point.
    def mount_point
      return nil unless formatted?

      filesystem.mount_point
    end

    # LVM physical volume defined on top of the device, either directly or
    # through an encryption layer.
    #
    # @return [LvmPv] nil if neither the raw device or its encrypted version
    #   are used as physical volume
    def lvm_pv
      descendants.detect { |dev| dev.is?(:lvm_pv) && dev.plain_blk_device == plain_device }
    end

    # LVM physical volume defined directly on top of the device (no encryption
    # or any other layer in between)
    #
    # @return [LvmPv] nil if the raw device is not used as physical volume
    def direct_lvm_pv
      descendants.detect { |dev| dev.is?(:lvm_pv) && dev.blk_device == self }
    end

    # MD array defined on top of the device, either directly or through an
    # encryption layer.
    #
    # @return [Md] nil if neither the raw device or its encrypted version
    #   are used by an MD RAID device
    def md
      descendants.detect { |dev| dev.is?(:md) && dev.plain_devices.include?(plain_device) }
    end

    # MD array defined directly on top of the device (no encryption or any
    # other layer in between)
    #
    # @return [Md] nil if the raw device is not used by any MD RAID device
    def direct_md
      descendants.detect { |dev| dev.is?(:md) && dev.devices.include?(self) }
    end

    # DM arrays defined on top of the device
    #
    # @return [Array<DmRaid>] empty if the device is not used by any DM RAID
    #   device
    def dm_raids
      children.select { |dev| dev.is?(:dm_raid) }
    end

    # Multipath device defined on top of the device
    #
    # @return [Multipath, nil] nil if the device is not part of any multipath
    def multipath
      children.find { |dev| dev.is?(:multipath) }
    end

    # Bcache device defined on top of the device, i.e. a Bcache device that uses
    # this one as backing device
    #
    # @return [Bcache, nil] nil if the device is not part of any bcache
    def bcache
      descendants.detect { |dev| dev.is?(:bcache) && dev.blk_device.plain_device == plain_device }
    end

    # Bcache caching set device defined on top of the device
    #
    # @return [BcacheCset, nil] nil if the device is not used as bcache caching set
    def bcache_cset
      descendants.detect do |dev|
        dev.is?(:bcache_cset) && dev.blk_devices.any? { |b| b.plain_device == plain_device }
      end
    end

    # Whether the device forms part of an LVM or MD RAID
    #
    # @return [Boolean]
    def part_of_lvm_or_md?
      !lvm_pv.nil? || !md.nil?
    end

    # Devices built on top of this device, to be used mainly by the Partitioner
    # to display which devices are using this one as its base.
    #
    # This does not include all the descendants, but only those multi-device
    # devices for which this is one of the components. For example, it will
    # include any LVM VG for which this device is one of its physical volumes
    # (directly or through an encryption) or any RAID having this device as
    # one of its members.
    #
    # @return [Array<Device>] a collection of MD RAIDs, DM RAIDs, volume groups,
    #   multipath, bcache and bcache_cset devices
    def component_of
      vg = lvm_pv ? lvm_pv.lvm_vg : nil
      (dm_raids + [vg] + [md] + [multipath] + [bcache] + [bcache_cset]).compact
    end

    # Equivalent of {#component_of} in which each device is represented by a
    # string.
    #
    # @return [Array<String>]
    def component_of_names
      # So far, all the possible elements on the array respond to #name
      component_of.map do |dev|
        if dev.respond_to?(:name)
          dev.name
        elsif dev.respond_to?(:display_name)
          dev.display_name
        else
          raise "Unexpected type of device #{dev.inspect}"
        end
      end
    end

    # Label of the filesystem, if any
    # @return [String, nil]
    def filesystem_label
      return nil unless blk_filesystem
      blk_filesystem.label
    end

    # full path of the udev by-label link or `nil` if it does not exist.
    # e.g. "/dev/disk/by-label/DATA"
    # @see #udev_paths
    # @return [String]
    def udev_full_label
      label = filesystem_label

      return nil if label.nil? || label.empty?
      File.join("/dev", "disk", "by-label", label)
    end

    # UUID of the filesystem, if any
    # @return [String, nil]
    def filesystem_uuid
      return nil unless blk_filesystem
      blk_filesystem.uuid
    end

    # full path of the udev by-uuid link or `nil` if it does not exist.
    # e.g. "/dev/disk/by-uuid/a1dc747af-6ef7-44b9-b4f8-d200a5f933ec"
    # @see #udev_paths
    # @return [String]
    def udev_full_uuid
      uuid = filesystem_uuid

      return nil if uuid.nil? || uuid.empty?
      File.join("/dev", "disk", "by-uuid", uuid)
    end

    # Type of the filesystem, if any
    # @return [Filesystems::Type, nil]
    def filesystem_type
      return nil unless blk_filesystem
      blk_filesystem.type
    end

    # Mount point of the filesystem, if any
    # @return [String, nil]
    def filesystem_mountpoint
      return nil unless blk_filesystem
      blk_filesystem.mount_path
    end

    # Non encrypted version of this device
    #
    # For most subclasses, this will simply return the device itself. To be
    # redefined by encryption-related subclasses.
    #
    # @return [BlkDevice]
    def plain_device
      self
    end

    # Checks whether a new filesystem (encrypted or not) should be created for
    # this device
    #
    # @param initial_devicegraph [Devicegraph] devicegraph to use as starting
    #   point when calculating the actions to perform
    # @return [Boolean]
    def to_be_formatted?(initial_devicegraph)
      return false unless blk_filesystem
      !blk_filesystem.exists_in_devicegraph?(initial_devicegraph)
    end

    # Last part of {#name}
    #
    # @example Get the device basename
    #   device.name     # => "/dev/sda"
    #   device.basename # => "sda"
    #
    # @return [String]
    def basename
      name.split("/").last
    end

    # Return hardware information for the device
    #
    # @return [OpenStruct,nil] Hardware information; nil if no information was found.
    #
    # @see Y2Storage::HWInfoReader
    def hwinfo
      Y2Storage::HWInfoReader.instance.for_device(name)
    end

    # Device vendor
    #
    # @see #hwinfo
    #
    # @return [String, nil] nil if vendor is unknown
    def vendor
      return nil if hwinfo.nil?
      hwinfo.vendor
    end

    # Device model
    #
    # @see #hwinfo
    #
    # @return [String, nil] nil if model is unknown
    def model
      return nil if hwinfo.nil?
      hwinfo.model
    end

    # Device bus (IDE, SATA, etc)
    #
    # @see #hwinfo
    #
    # @return [String, nil] nil if bus is unknown
    def bus
      return nil if hwinfo.nil?
      hwinfo.bus
    end

    # Size of the space that could be theoretically reclaimed by shrinking the
    # device
    #
    # It does not guarantee the new free space can really be used. Other
    # restrictions (like alignment or the max number of partitions) may apply.
    #
    # @return [DiskSize]
    def recoverable_size
      return DiskSize.zero unless resize_info.resize_ok?
      size - resize_info.min_size
    end

  protected

    # Values for volume specification matching
    #
    # @see MatchVolumeSpec
    def volume_match_values
      {
        mount_point:  filesystem_mountpoint,
        size:         size,
        fs_type:      filesystem_type,
        partition_id: nil
      }
    end

    def types_for_is
      super << :blk_device
    end
  end
end
