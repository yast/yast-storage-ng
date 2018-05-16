#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
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
require "storage"
require "fileutils"
require "y2packager/repository"
require "y2storage/disk_size"
require "y2storage/blk_device"
require "y2storage/lvm_pv"
require "y2storage/partition_id"
require "y2storage/existing_filesystem"

Yast.import "Arch"

module Y2Storage
  #
  # Class to analyze the disk devices (the storage setup) of the existing system:
  # Check the existing disk devices (Dasd or Disk) and their partitions what candidates
  # there are to install on, typically eliminate the installation media from that list
  # (unless there is no other disk), check if there already are any
  # partitions that look like there was a Linux system previously installed
  # on that machine, check if there is a Windows partition that could be
  # resized.
  #
  # Some of those operations involve trying to mount the underlying filesystem.
  class DiskAnalyzer
    include Yast::Logger

    NO_INSTALLATION_IDS =
      [
        PartitionId::SWAP,
        PartitionId::EXTENDED,
        PartitionId::LVM
      ]

    # Maximum number of checks for "expensive" operations.
    DEFAULT_CHECK_LIMIT = 10

    def initialize(devicegraph)
      @devicegraph = devicegraph
    end

    # Partitions containing an installation of MS Windows
    #
    # This involves mounting any Windows-like partition to check if there are
    # some typical directories (/windows/system32).
    #
    # @param disks [Disk, String] disks to analyze. All disks by default.
    # @return [Array<Partition>]
    def windows_partitions(*disks)
      data_for(*disks, :windows_partitions) { |d| find_windows_partitions(d) }
    end

    # Linux partitions.
    #
    # @see PartitionId.linux_system_ids
    #
    # @param disks [Disk, String] disks to analyze. All disks by default.
    # @return [Array<Partition>]
    def linux_partitions(*disks)
      data_for(*disks, :linux_partitions, &:linux_system_partitions)
    end

    # Release names of installed systems for every disk.
    #
    # @param disks [Disk, String] disks to analyze. All disks by default.
    # @return [Array<String>] release names
    def installed_systems(*disks)
      data_for(*disks, :installed_systems) { |d| find_installed_systems(d) }
    end

    # Release names of installed Windows systems for every disk.
    #
    # @param disks [Disk, String] disks to analyze. All disks by default.
    # @return [Array<String>] release names
    def windows_systems(*disks)
      data_for(*disks, :windows_systems) { |d| find_windows_systems(d) }
    end

    # Release names of installed Linux systems for every disk.
    #
    # @param disks [Disk, String] disks to analyze. All disks by default.
    # @return [Array<String>] release names
    def linux_systems(*disks)
      data_for(*disks, :linux_systems) { |d| find_linux_systems(d) }
    end

    # All fstabs found in the system
    #
    # FIXME: this method is not using the {#data_for} caching mechanism. The reason
    # is because fstab information needs to be stored by filesystem, but {#data_for}
    # saves information by disk. As a consequence, this method could mount a device
    # that was already mounted previously to read some information on it, for
    # example the {#installed_systems}.
    #
    # @return [Array<Fstab>]
    def fstabs
      @fstabs ||= find_fstabs
    end

    # Disks that are suitable for installing Linux.
    #
    # @return [Array<Disk>] candidate disks
    def candidate_disks
      return @candidate_disks if @candidate_disks
      @candidate_disks = find_candidate_disks
      log.info("Found candidate disks: #{@candidate_disks}")
      @candidate_disks
    end

    # Look up devicegraph element by device name.
    #
    # @return [Device]
    def device_by_name(name)
      # Using BlkDevice because it is necessary to search in both, Dasd and Disk.
      BlkDevice.find_by_name(devicegraph, name)
    end

  private

    attr_reader :devicegraph

    # Gets data for a set of disks, stores it and returns that data.
    #
    # @param disks [Disk, String] disks to analyze. All disks by default.
    # @param data [Symbol] data name.
    def data_for(*disks, data)
      @disks_data ||= {}
      @disks_data[data] ||= {}
      disks = disks_collection(disks)
      disks.each do |disk|
        @disks_data[data][disk.name] ||= yield(disk)
      end
      disks.map { |d| @disks_data[data][d.name] }.flatten.compact
    end

    # Obtains a list of disk devices.
    #
    # @param disks [Array<Dasd, Disk, String>] disk device to analyze.
    #   All disk devices by default.
    # @return [Array<Dasd, Disk>]
    def disks_collection(disks)
      disks = devicegraph.disk_devices if disks.empty?
      # Using BlkDevice because it is necessary to search in both, Dasd and Disk.
      disks = disks.map { |d| d.is_a?(String) ? BlkDevice.find_by_name(devicegraph, d) : d }
      disks.compact
    end

    # @see #windows_partitions
    def find_windows_partitions(disk)
      return nil unless windows_architecture?
      disk.possible_windows_partitions.select { |p| windows_partition?(p) }
    end

    # Checks whether the architecture of the system is supported by
    # MS Windows
    #
    # @return [Boolean]
    def windows_architecture?
      # Should we include ARM here?
      Yast::Arch.x86_64 || Yast::Arch.i386
    end

    # Check if 'partition' is a MS Windows partition that could possibly be resized.
    #
    # @param partition [Partition] partition to check.
    # @return [Boolean] 'true' if it is a Windows partition, 'false' if not.
    def windows_partition?(partition)
      log.info("Checking if #{partition.name} is a windows partition")
      filesystem = partition.filesystem
      is_win = filesystem && filesystem.detect_content_info.windows?

      log.info("#{partition.name} is a windows partition") if is_win
      is_win
    end

    # Obtain release names of installed systems in a disk.
    #
    # @param disk [Disk] disk to check
    # @return [Array<String>] release names
    def find_installed_systems(disk)
      windows_systems(disk) + linux_systems(disk)
    end

    # Obtain release names of installed Windows systems in a disk.
    #
    # @param disk [Disk] disk to check
    # @return [Array<String>] release names
    def find_windows_systems(disk)
      systems = []
      systems << "Windows" unless windows_partitions(disk).empty?
      systems
    end

    # Obtain release names of installed Linux systems in a disk.
    #
    # @param disk [Disk] disk to check
    # @return [Array<String>] release names
    def find_linux_systems(disk)
      filesystems = linux_partitions(disk).map(&:filesystem)
      filesystems << disk.filesystem
      filesystems.compact!
      filesystems.map { |f| release_name(f) }.compact
    end

    # Finds fstab files in all filesystems
    #
    # @see #suitable_root_filesystems
    #
    # @return [Array<Fstab>]
    def find_fstabs
      suitable_root_filesystems.map { |f| fstab(f) }.compact
    end

    # Filesystems that could contain a Linux installation
    #
    # @return [Array<Filesystems::Base>]
    def suitable_root_filesystems
      devicegraph.filesystems.select { |f| f.type.root_ok? }
    end

    # Fstab in the filesystem
    #
    # @param filesystem [Filesystems::Base]
    # @return [Fstab, nil] nil if the filesystem does not contain a fstab file
    def fstab(filesystem)
      fs = ExistingFilesystem.new(filesystem)
      fs.fstab
    end

    def release_name(filesystem)
      fs = ExistingFilesystem.new(filesystem)
      fs.release_name
    end

    # TODO: there is no reason to initally discard usb devices. The behavior is
    # kept to avoid big changes in release phase.
    #
    # Finds disk devices that are suitable for installing Linux.
    #
    # @note Usb devices are considered as candidate disk only if there are no
    #   other candidate disks.
    #
    # @return [Array<BlkDevice>] candidate devices
    def find_candidate_disks
      candidates = find_non_usb_candidate_disks
      return candidates if candidates.any?

      find_usb_candidate_disks
    end

    # Finds non usb devices that are suitable for installing Linux
    #
    # @return [Array<BlkDevice>] candidate devices
    def find_non_usb_candidate_disks
      devicegraph.disk_devices.select { |d| !d.usb? && candidate_disk?(d) }
    end

    # Finds usb devices that are suitable for installing Linux
    #
    # @return [Array<BlkDevice>] candidate devices
    def find_usb_candidate_disks
      devicegraph.disk_devices.select { |d| d.usb? && candidate_disk?(d) }
    end

    # Checks whether a device can be used as candidate disk for installation
    #
    # @note A device is candidate for installation if no filesystem belonging
    #   to the device is mounted and the device does not contain a repository
    #   for installation.
    #
    # @param device [BlkDevice]
    # @return [Boolean]
    def candidate_disk?(device)
      !contain_mounted_filesystem?(device) &&
        !contain_installation_repository?(device)
    end

    # Checks whether a device contains a mounted filesystem
    #
    # @see #device_filesystems, #mounted_filesystem?
    #
    # @param device [BlkDevice]
    # @return [Boolean]
    def contain_mounted_filesystem?(device)
      device_filesystems(device).any? { |f| mounted_filesystem?(f) }
    end

    # All filesystems inside a device
    #
    # @note The device could be directly formatted or the filesystem could belong
    #   to a partition inside the device. Moreover, when the device (on any of its
    #   partitions) is used as LVM PV, all filesystem inside the LVM VG are considered
    #   as belonging to the device.
    #
    # @param device [BlkDevice]
    # @return [Array<BlkFilesystem>]
    def device_filesystems(device)
      device.descendants.select { |d| d.is?(:blk_filesystem) }
    end

    # Checks whether a filesystem is currently mounted
    #
    # @param filesystem [Filesystems::Base]
    # @return [Boolean]
    def mounted_filesystem?(filesystem)
      filesystem.mount_point && filesystem.mount_point.active?
    end

    # Checks whether a device contains an installation repository
    #
    # For all possible names of the given device, it is checked if any of that
    # names is included in the URI of an installation repository (see
    # {#repositories_devices}). Note that the names of all devices inside the
    # given device are considered as names of the given device (see #{device_names}),
    # (e.g., when a disk contains a partition being used as LVM PV, the names of the
    # LVM LVs are considered as names of the disk).
    #
    # @param device [BlkDevice]
    # @return [Boolean]
    def contain_installation_repository?(device)
      device_names(device).any? { |n| repositories_devices.include?(n) }
    end

    # All possible device names of a device
    #
    # Device names includes the kernel name and all udev names given by libstorage-ng.
    # Moreover, it includes the names of all devices inside the given device
    # (e.g., names of partitions inside a disk). Note that when a device contains a
    # partition being used as LVM PV, the names of the LVM LVs are considered as names
    # of the device.
    #
    # @param device [BlkDevice]
    # @return [Array<String>]
    def device_names(device)
      devices = all_devices_from_device(device)

      names = devices.map { |d| d.udev_full_all.prepend(d.name) }
      names.flatten.compact.uniq
    end

    # All blk devices defined from a device, including the given device
    # (e.g., a disk and all its partitions)
    #
    # Note that when a device contains a partition being used as LVM PV, all LVM LVs are included.
    #
    # @param device [BlkDevice]
    # @return [Array<BlkDevice>]
    def all_devices_from_device(device)
      devices = device.descendants.select { |d| d.is?(:blk_device) }
      devices.prepend(device)
    end

    # Device names indicated in the URI of the installation repositories
    #
    # @see #local_repositories
    #
    # @return [Array<String>]
    def repositories_devices
      return @repositories_devices if @repositories_devices

      @repositories_devices = local_repositories.map { |r| repository_devices(r) }.flatten
    end

    # TODO: This method should be moved to Y2Packager::Repository class
    #
    # Device names indicated in the URI of an installation repository
    #
    # For example:
    #   "hd:/subdir?device=/dev/sda1&filesystem=reiserfs" => ["/dev/sda1"]
    #   "dvd:/?devices=/dev/sda,/dev/sdb" => ["/dev/sda", "/dev/sdb"]
    #
    # @param repository [Y2Packager::Repository]
    # @return [Array<String>]
    def repository_devices(repository)
      match_data = repository.url.to_s.match(/.*device[s]?=([^&]*)/)
      return [] unless match_data

      match_data[1].split(",").map(&:strip)
    end

    # Local repositories used during installation
    #
    # @return [Array<Y2Packager::Repository>]
    def local_repositories
      Y2Packager::Repository.all.select(&:local?)
    end
  end
end
