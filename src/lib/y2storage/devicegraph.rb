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
require "y2storage/actiongraph"
require "y2storage/blk_device"
require "y2storage/disk"
require "y2storage/partition"
require "y2storage/filesystems/base"
require "y2storage/filesystems/blk_filesystem"
require "y2storage/filesystems/nfs"

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

    # @!clear
    #   Removes all devices
    storage_forward :clear

    # @!check
    #   @raise [Exception] if the devicegraph contains logic errors
    #     (like, for example, a duplicated id)
    storage_forward :check

    # @!used_features
    #   @return [Fixnum] bit-field with the used features of the devicegraph
    storage_forward :used_features

    # @!copy(dest)
    #   Copies content to another devicegraph
    #
    #   @param dest [Devicegraph] destination devicegraph
    storage_forward :copy

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
      origin = from ? from.to_storage_value : to_storage_value.storage.probed
      graph = ::Storage::Actiongraph.new(to_storage_value.storage, origin, to_storage_value)
      Actiongraph.new(graph)
    end

    # @return [Array<Disk>]
    def disks
      Disk.all(self)
    end

    # @return [Array<Partition>]
    def partitions
      Partition.all(self)
    end

    # @return [Array<Filesystems::Base>]
    def filesystems
      Filesystems::Base.all(self)
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
  end
end
