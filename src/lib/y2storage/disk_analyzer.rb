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
  # there areto install on, typically eliminate the installation media from that list
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
      data_for(*disks, :linux_partitions) { |d| d.linux_system_partitions }
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
      return [] if filesystems.empty?
      filesystems.map { |f| release_name(f) }.compact
    end

    def release_name(filesystem)
      fs = ExistingFilesystem.new(filesystem)
      fs.release_name
    end

    # Find disk devices that are suitable for installing Linux.
    # Put any USB disks to the end of that array.
    #
    # @return [Array<Disk>] candidate disks
    def find_candidate_disks
      @installation_disks = find_installation_disks

      usb_disks, non_usb_disks = devicegraph.disk_devices.partition { |d| d.usb? }

      # Try with non-USB disks first.
      disks = remove_installation_disks(non_usb_disks)
      return disks unless disks.empty?

      log.info("No non-USB candidate disks left after eliminating installation disks")
      log.info("Trying with USB disks")
      disks = remove_installation_disks(usb_disks)
      return disks unless disks.empty?

      # We don't want to install on our installation disk if there is any other way.
      log.info("No candidate disks left after eliminating installation disks")
      log.info("Trying with non-USB installation disks")
      disks = @installation_disks.select { |d| !d.usb? }
      return disks unless disks.empty?

      log.info("Still no candidate disks left")
      log.info("Trying with installation disks out of sheer desperation")
      @installation_disks
    end

    # Find disk devices that look like the current installation medium
    # (the medium we just booted from to start the installation).
    #
    # This should be limited because some architectures (s/390) tend
    # to have a large number of disks, and checking if a disk is an
    # installation disk involves mounting and unmounting each partition
    # on that disk.
    #
    # @return [Array<Disk>]
    def find_installation_disks
      usb_disks, non_usb_disks = devicegraph.disk_devices.partition { |d| d.usb? }
      disks = usb_disks + non_usb_disks
      disks = disks.first(DEFAULT_CHECK_LIMIT)
      disks.select { |d| installation_disk?(d) }
    end

    # Check if a disk is our installation disk - the medium we just booted
    # and started the installation from. This will check all filesystems on
    # that disk.
    #
    # @param disk [Disk] device to check
    # @return [Boolean] 'true' if the disk is an installation disk
    def installation_disk?(disk)
      log.info("Checking if #{disk.name} is an installation disk")
      # Check if there is a filesystem directly on the disk (without partition table).
      # This is very common for installation media such as USB sticks.
      return installation_volume?(disk) if disk.partition_table.nil?

      disk.partitions.each do |partition|
        if NO_INSTALLATION_IDS.include?(partition.id)
          log.info "Skipping #{partition} (ID #{partition.id.inspect})"
          next
        elsif installation_volume?(partition)
          return true
        end
      end

      false
    end

    # Check if a volume (a partition or a disk without a partition table) is
    # our installation medium - the medium we just booted and started the
    # installation from.
    #
    # The method to achieve this is to try to mount the filesystem and check
    # if there is a file /control.xml and compare its content to the
    # /control.xml in the inst-sys. We cannot simply compare device
    # minor/major IDs since the inst-sys is in a RAM disk (copied from the
    # installation medium).
    #
    # @param device [#name] device to check
    # @return [Boolean] 'true' if the volume is an installation volume
    def installation_volume?(device)
      log.info("Checking if #{device.name} is an installation medium")
      return false unless device.filesystem
      fs = ExistingFilesystem.new(device.filesystem)
      log.info("#{device.name} is an installation medium") if fs.installation_medium?
      fs.installation_medium?
    end

    # Remove any installation disks from 'disks' and return a disks array
    # containing the disks that are not installation media.
    #
    # @param disks [Array<Disk>]
    # @return [Array<Disk>] non-installation disks
    def remove_installation_disks(disks)
      # We can't simply use
      #   disks -= @installation_disks
      # because the list elements (from libstorage) don't provide a .hash method.
      # Comparing device names ("/dev/sda"...) instead.
      disks.delete_if { |disk| @installation_disks.map(&:name).include?(disk.name) }
    end
  end
end
