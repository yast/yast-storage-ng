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

    # All BIOS RAIDs in the devicegraph, sorted by name
    #
    # @note BIOS RAIDs are the set composed by MD BIOS RAIDs and DM RAIDs.
    #
    # @return [Array<DmRaid, MdMember>]
    def bios_raids
      devices = dm_raids + md_member_raids
      devices.sort { |a, b| a.compare_by_name(b) }
    end

    # All Software RAIDs in the devicegraph, sorted by name
    #
    # @note Software RAIDs are all Md devices except MdMember and MdContainer devices.
    #
    # @return [Array<Md>]
    def software_raids
      md_raids.select(&:software_defined?)
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
      # NOTE: to avoid sorting something that is going to be sorted again, we
      # could call Disk.all instead of #disks, Multipath.all instead
      # of #multipaths and so on. But the current implementation is more
      # readable and the impact is probably unnoticeable.

      multi_disk_devs = multipaths + bios_raids
      parent_devs = multi_disk_devs.map(&:parents).flatten
      # Use #reject because Array#- is not trustworthy with SWIG
      devices = (multi_disk_devs + dasds + disks).reject { |d| parent_devs.include?(d) }
      devices.sort { |a, b| a.compare_by_name(b) }
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
      filesystem = filesystems.find { |i| i.mountpoint == mountpoint }
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

    # @return [Array<FreeDiskSpace>]
    def free_disk_spaces
      disks.reduce([]) { |sum, disk| sum + disk.free_spaces }
    end

    # Removes a Md raid and all its descendants
    #
    # @param md [Md]
    #
    # @raise [ArgumentError] if the md does not exist in the devicegraph
    def remove_md(md)
      if md.nil? || !md_raids.include?(md)
        raise ArgumentError, "Md RAID not found"
      end

      md.remove_descendants
      remove_device(md)
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
  end
end
