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

require "pp"
require "tempfile"
require "y2storage/actiongraph"
require "y2storage/blk_device"
require "y2storage/disk"
require "y2storage/fake_device_factory"
require "y2storage/filesystems/base"
require "y2storage/filesystems/blk_filesystem"
require "y2storage/filesystems/nfs"
require "y2storage/lvm_lv"
require "y2storage/lvm_vg"
require "y2storage/md"
require "y2storage/md_member"
require "y2storage/partition"
require "y2storage/storage_class_wrapper"
require "y2storage/storage_manager"

module Y2Storage
  # The master container of libstorage.
  #
  # A Devicegraph object represents a state of the system regarding its storage
  # devices (both physical and logical). It can be the probed state (read from
  # the inspected system) or a possible target state.
  #
  # This is a wrapper for Storage::Devicegraph
  class Devicegraph
    include Yast::Logger
    include StorageClassWrapper
    wrap_class Storage::Devicegraph

    storage_forward :==
    storage_forward :!=

    # @!method load(filename)
    #   Reads the devicegraph from a xml file (libstorage format)
    storage_forward :load

    # @!method save(filename)
    #   Writes the devicegraph to a xml file (libstorage format)
    storage_forward :save

    # @!write_graphviz(filename, graphviz_flags)
    #   Writes the devicegraph to a file in Graphviz format
    storage_forward :write_graphviz

    # @!method empty?
    #   Checks whether the devicegraph is empty (no devices)
    storage_forward :empty?

    # @!method clear
    #   Removes all devices
    storage_forward :clear

    # @!method check
    #   @raise [Exception] if the devicegraph contains logic errors
    #     (like, for example, a duplicated id)
    storage_forward :check

    # @!method used_features
    #   @return [Integer] bit-field with the used features of the devicegraph
    storage_forward :used_features

    # @!method copy(dest)
    #   Copies content to another devicegraph
    #
    #   @param dest [Devicegraph] destination devicegraph
    storage_forward :copy

    # @!method find_device(device)
    #   Find a device by its {Device#sid sid}
    #
    #   @return [Device]
    storage_forward :find_device, as: "Device"

    # @!method remove_device(device)
    #
    # Removes a device from the devicegraph. Only use this
    # method if there is no special method to delete a device,
    # e.g., PartitionTable.delete_partition() or LvmVg.delete_lvm_lv().
    #
    # @see #remove_md
    # @see #remove_lvm_vg
    # @see #remove_btrfs_subvolume
    #
    # @param device [Device, Integer] a device or its {Device#sid sid}
    #
    # @raise [DeviceNotFoundBySid] if a device with given sid is not found
    storage_forward :remove_device
    private :remove_device

    # Creates a new devicegraph with the information read from a file
    #
    # @param filename [String]
    # @return [Devicegraph]
    def self.new_from_file(filename)
      storage = Y2Storage::StorageManager.instance.storage
      devicegraph = ::Storage::Devicegraph.new(storage)
      Y2Storage::FakeDeviceFactory.load_yaml_file(devicegraph, filename)
      new(devicegraph)
    end

    # @return [Devicegraph]
    def dup
      new_graph = ::Storage::Devicegraph.new(to_storage_value.storage)
      copy(new_graph)
      Devicegraph.new(new_graph)
    end
    alias_method :duplicate, :dup

    # Set of actions needed to get this devicegraph
    #
    # By default the starting point is the probed devicegraph
    #
    # @param from [Devicegraph] starting graph to calculate the actions
    #       If nil, the probed devicegraph is used.
    # @return [Actiongraph]
    def actiongraph(from: nil)
      storage_object = to_storage_value.storage || StorageManager.instance.storage
      origin = from ? from.to_storage_value : storage_object.probed
      graph = ::Storage::Actiongraph.new(storage_object, origin, to_storage_value)
      Actiongraph.new(graph)
    end

    # All the DASDs in the devicegraph, sorted by name
    #
    # @note Based on the libstorage classes hierarchy, DASDs are not considered to be disks.
    # See #disk_devices for a method providing the whole list of both disks and DASDs.
    # @see #disk_devices
    #
    # @return [Array<Dasd>]
    def dasds
      Dasd.sorted_by_name(self)
    end

    # All the disks in the devicegraph, sorted by name
    #
    # @note Based on the libstorage classes hierarchy, DASDs are not considered to be disks.
    # See #disk_devices for a method providing the whole list of both disks and DASDs.
    # @see #disk_devices
    #
    # @return [Array<Disk>]
    def disks
      Disk.sorted_by_name(self)
    end

    # All the multipath devices in the devicegraph, sorted by name
    #
    # @return [Array<Multipath>]
    def multipaths
      Multipath.sorted_by_name(self)
    end

    # All the DM RAIDs in the devicegraph, sorted by name
    #
    # @return [Array<DmRaid>]
    def dm_raids
      DmRaid.sorted_by_name(self)
    end

    # All the MD RAIDs in the devicegraph, sorted by name
    #
    # @return [Array<Md>]
    def md_raids
      Md.sorted_by_name(self)
    end

    # All MD BIOS RAIDs in the devicegraph, sorted by name
    #
    # @note The class MdMember is used by libstorage-ng to represent MD BIOS RAIDs.
    #
    # @return [Array<MdMember>]
    def md_member_raids
      MdMember.sorted_by_name(self)
    end

    # All RAIDs in the devicegraph, sorted by name
    #
    # @return [Array<Md, MdMember, DmRaid>]
    def raids
      BlkDevice.sorted_by_name(self).select { |d| d.is?(:raid) }
    end

    # All BIOS RAIDs in the devicegraph, sorted by name
    #
    # @note BIOS RAIDs are the set composed by MD BIOS RAIDs and DM RAIDs.
    #
    # @return [Array<DmRaid, MdMember>]
    def bios_raids
      BlkDevice.sorted_by_name(self).select { |d| d.is?(:bios_raid) }
    end

    # All Software RAIDs in the devicegraph, sorted by name
    #
    # @note Software RAIDs are all Md devices except MdMember and MdContainer devices.
    #
    # @return [Array<Md>]
    def software_raids
      BlkDevice.sorted_by_name(self).select { |d| d.is?(:software_raid) }
    end

    # All the devices that are usually treated like disks by YaST, sorted by
    # name
    #
    # Currently this method returns an array including all the multipath
    # devices and BIOS RAIDs, as well as disks and DASDs that are not part
    # of any of the former.
    # @see #disks
    # @see #dasds
    # @see #multipaths
    # @see #bios_raids
    #
    # @return [Array<Dasd, Disk, Multipath, DmRaid, MdMember>]
    def disk_devices
      BlkDevice.sorted_by_name(self).select { |d| d.is?(:disk_device) }
    end

    # All partitions in the devicegraph, sorted by name
    #
    # @return [Array<Partition>]
    def partitions
      Partition.sorted_by_name(self)
    end

    # @return [Array<Filesystems::Base>]
    def filesystems
      Filesystems::Base.all(self)
    end

    # @param mountpoint [String] mountpoint of the filesystem (e.g. "/").
    # @return [Boolean]
    def filesystem_in_network?(mountpoint)
      filesystem = filesystems.find { |i| i.mount_path == mountpoint }
      return false if filesystem.nil?
      filesystem.in_network?
    end

    # @return [Array<Filesystems::BlkFilesystem>]
    def blk_filesystems
      Filesystems::BlkFilesystem.all(self)
    end

    # @return [Array<Filesystem::Nfs>]
    def nfs_mounts
      Filesystems::Nfs.all(self)
    end

    # All the LVM volume groups in the devicegraph, sorted by name
    #
    # @return [Array<LvmVg>]
    def lvm_vgs
      LvmVg.sorted_by_name(self)
    end

    # @return [Array<LvmPv>]
    def lvm_pvs
      LvmPv.all(self)
    end

    # All the LVM logical volumes in the devicegraph, sorted by name
    #
    # @return [Array<LvmLv>]
    def lvm_lvs
      LvmLv.sorted_by_name(self)
    end

    # All the block devices in the devicegraph, sorted by name
    #
    # @return [Array<BlkDevice>]
    def blk_devices
      BlkDevice.sorted_by_name(self)
    end

    # Find device with given name e.g. /dev/sda3
    # @param [String] name
    # @return [Device, nil] if found Device and if not, then nil
    def find_by_name(name)
      BlkDevice.find_by_name(self, name) || lvm_vgs.find { |vg| vg.name == name }
    end

    # Finds a device by any name including any symbolic link in the /dev directory
    #
    # This is different from {BlkDevice.find_by_any_name} in several ways:
    #
    # * It will find any matching device, not only block devices (e.g. LVM VGs
    #   also have a name but are not block devices).
    # * It can be called on any devicegraph, not only probed.
    # * It uses a system lookup only when necessary (i.e. all the cheaper
    #   methods for finding the device have been unsuccessful).
    # * It avoids system lookup in potentially risky scenarios (like an outdated
    #   {StorageManager#probed}).
    #
    # @param name [String] can be a kernel name like "/dev/sda1" or any symbolic
    #   link below the /dev directory
    # @return [Device, nil] the found device, nil if no device matches the name
    def find_by_any_name(name)
      # First check using the device name
      result = find_by_name(name)
      # If not found, check udev names directly handled by libstorage-ng
      result ||= blk_devices.find { |dev| dev.udev_full_all.include?(name) }
      log.info "Device #{result.inspect} found by its libstorage-ng name #{name}"
      return result if result

      # If no result yet, there is still a chance using the slower
      # BlkDevice.find_by_any_name. Unfortunatelly this only works in the
      # probed devicegraph by design. Moreover it can only be safely called
      # under certain circumstances.
      if !udev_lookup_possible?
        log.info "System lookup cannot be used to find #{name}"
        return nil
      end

      probed = StorageManager.instance.probed
      found = BlkDevice.find_by_any_name(probed, name)
      if found.nil?
        log.info "Device #{name} not found via system lookup"
        return nil
      end

      result = find_device(found.sid)
      log.info "Result of system lookup for #{name}: #{result.inspect}"
      result
    end

    # @return [Array<FreeDiskSpace>]
    def free_disk_spaces
      disks.reduce([]) { |sum, disk| sum + disk.free_spaces }
    end

    # Removes a Md raid and all its descendants
    #
    # It also removes other devices that may have become useless, like the
    # LvmPv devices of any removed LVM volume group.
    #
    # @see #remove_lvm_vg
    #
    # @param md [Md]
    #
    # @raise [ArgumentError] if the md does not exist in the devicegraph
    def remove_md(md)
      raise(ArgumentError, "Incorrect device #{md.inspect}") unless md && md.is?(:md)
      remove_with_dependants(md)
    end

    # Removes an LVM VG, all its descendants and the associated PV devices
    #
    # Note this removes the LvmPv devices, not the real block devices hosting
    # those physical volumes.
    #
    # @param vg [LvmVg]
    #
    # @raise [ArgumentError] if the volume group does not exist in the devicegraph
    def remove_lvm_vg(vg)
      raise(ArgumentError, "Incorrect device #{vg.inspect}") unless vg && vg.is?(:lvm_vg)
      remove_with_dependants(vg)
    end

    # Removes a Btrfs subvolume and all its descendants
    #
    # @param subvol [BtrfsSubvolume]
    #
    # @raise [ArgumentError] if the subvolume does not exist in the devicegraph
    def remove_btrfs_subvolume(subvol)
      if subvol.nil? || !subvol.is?(:btrfs_subvolume)
        raise ArgumentError, "Incorrect device #{subvol.inspect}"
      end
      remove_with_dependants(subvol)
    end

    # Removes an NFS mount and all its descendants
    #
    # @param nfs [Filesystems::Nfs]
    #
    # @raise [ArgumentError] if the NFS filesystem does not exist in the devicegraph
    def remove_nfs(nfs)
      raise(ArgumentError, "Incorrect device #{nfs.inspect}") unless nfs && nfs.is?(:nfs)
      remove_with_dependants(nfs)
    end

    # FIXME
    # Removes an MountPoint and all its descendants
    #
    # @param mount_point [MountPoint]
    #
    # @raise [ArgumentError] if the MountPoint does not exist in the devicegraph
    def remove_mount_point(mount_point)
      if mount_point.nil? || !mount_point.is?(:mount_point)
        raise(ArgumentError, "Incorrect device #{mount_point.inspect}")
      end

      remove_with_dependants(mount_point)
    end

    # String to represent the whole devicegraph, useful for comparison in
    # the tests.
    #
    # The format is deterministic (always equal for equivalent devicegraphs)
    # and based in the structure generated by YamlWriter
    # @see Storage::YamlWriter
    #
    # @return [String]
    def to_str
      PP.pp(recursive_to_a(device_tree), "")
    end

    # Generates a string representation of the devicegraph in xml format
    #
    # @note The library offers a #save method to obtain the devicegraph in xml
    #   format, but it requires a file path where to dump the result. For this
    #   reason a temporary file is used here, but it would not be necessary if
    #   the library directly returns the xml string without save it into a file.
    #
    # @return [String]
    def to_xml
      file = Tempfile.new("devicegraph.xml")
      save(file.path)
      file.read
    ensure
      # Do not wait for garbage collector and delete the file right away
      file.close
      file.unlink
    end

  private

    # Copy of a device tree where hashes have been substituted by sorted
    # arrays to ensure consistency
    #
    # @see YamlWriter#yaml_device_tree
    def recursive_to_a(tree)
      case tree
      when Array
        tree.map { |element| recursive_to_a(element) }
      when Hash
        tree.map { |key, value| [key, recursive_to_a(value)] }.sort_by(&:first)
      else
        tree
      end
    end

    def device_tree
      writer = Y2Storage::YamlWriter.new
      writer.yaml_device_tree(self)
    end

    # Removes a device, all its descendants and also the potential orphans of
    # all the removed devices.
    #
    # @see Device#potential_orphans
    #
    # @param device [Device]
    # @param keep [Array<Device>] used to control the recursive calls
    #
    # @raise [ArgumentError] if the device does not exist in the devicegraph
    def remove_with_dependants(device, keep: [])
      raise(ArgumentError, "No device provided") if device.nil?
      raise(ArgumentError, "Device not found") unless device.exists_in_devicegraph?(self)

      children = device.children
      until children.empty?
        remove_with_dependants(children.first, keep: keep + [device])
        children = device.children
      end

      orphans = device.respond_to?(:potential_orphans) ? device.potential_orphans : []
      remove_device(device)

      orphans.each do |dev|
        next if keep.include?(dev)

        dev.remove_descendants
        remove_device(dev)
      end
    end

    # Whether it's reasonably safe to use BlkDevice.find_by_any_name
    #
    # @return [Boolean]
    def udev_lookup_possible?
      # Checking when the operation is safe is quite tricky, since we must
      # ensure than the list of block devices in #probed matches 1:1 the list
      # of block devices in the system.
      #
      # Although it's not 100% precise, checking whether commit has not been
      # called provides a seasonable result.
      !StorageManager.instance.committed?
    end
  end
end
