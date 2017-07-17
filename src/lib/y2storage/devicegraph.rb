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
    #   @return [Fixnum] bit-field with the used features of the devicegraph
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

    # All the DASDs in the devicegraph
    #
    # @note Based on the libstorage classes hierarchy, DASDs are not considered to be disks.
    # See #disk_devices for a method providing the whole list of both disks and DASDs.
    # @see #disk_devices
    #
    # @return [Array<Dasd>]
    def dasds
      Dasd.all(self)
    end

    # All the disks in the devicegraph
    #
    # @note Based on the libstorage classes hierarchy, DASDs are not considered to be disks.
    # See #disk_devices for a method providing the whole list of both disks and DASDs.
    # @see #disk_devices
    #
    # @return [Array<Disk>]
    def disks
      Disk.all(self)
    end

    # All the multipath devices in the devicegraph
    #
    # @return [Array<Multipath>]
    def multipaths
      Multipath.all(self)
    end

    # All the devices that are usually treated like disks by YaST
    #
    # Currently this method returns an array including all the multipath
    # devices, as well as disks and DASDs that are not part of a multipath.
    # @see #disks
    # @see #dasds
    # @see #multipaths
    #
    # @return [Array<Dasd, Disk, Multipath>]
    def disk_devices
      mp_parents = multipaths.map(&:parents).flatten
      # Use #reject because Array#- is not trustworthy with SWIG
      (multipaths + dasds + disks).reject { |d| mp_parents.include?(d) }
    end

    # @return [Array<Partition>]
    def partitions
      Partition.all(self)
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

    # @return [Array<LvmVg>]
    def lvm_vgs
      LvmVg.all(self)
    end

    # @return [Array<LvmPv>]
    def lvm_pvs
      LvmPv.all(self)
    end

    # @return [Array<LvmLv>]
    def lvm_lvs
      LvmLv.all(self)
    end

    # @return [Array<Md>]
    def md_raids
      Md.all(self)
    end

    # @return [Array<FreeDiskSpace>]
    def free_disk_spaces
      disks.reduce([]) { |sum, disk| sum + disk.free_spaces }
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
