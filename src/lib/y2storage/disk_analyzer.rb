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
require "y2storage/disk"
require "y2storage/lvm_pv"
require "y2storage/partition_id"
require "y2storage/existing_filesystem"

Yast.import "Arch"

module Y2Storage
  #
  # Class to analyze the disks (the storage setup) of the existing system:
  # Check the existing disks and their partitions what candidates there are
  # to install on, typically eliminate the installation media from that list
  # (unless there is no other disk), check if there already are any
  # partitions that look like there was a Linux system previously installed
  # on that machine, check if there is a Windows partition that could be
  # resized.
  #
  # Some of those operations involve trying to mount the underlying
  # filesystem.
  #
  class DiskAnalyzer
    include Yast::Logger

    LINUX_PARTITION_IDS =
      [
        PartitionId::LINUX,
        PartitionId::SWAP,
        PartitionId::LVM,
        PartitionId::RAID
      ]

    WINDOWS_PARTITION_IDS =
      [
        PartitionId::NTFS,
        PartitionId::DOS32,
        PartitionId::DOS16,
        PartitionId::DOS12,
        PartitionId::WINDOWS_BASIC_DATA,
        PartitionId::MICROSOFT_RESERVED
      ]

    NO_INSTALLATION_IDS =
      [
        PartitionId::SWAP,
        PartitionId::EXTENDED,
        PartitionId::LVM
      ]

    DEFAULT_DISKS_LIMIT = 10

    def initialize(devicegraph)
      @devicegraph = devicegraph
      # FIXME: The following line is here just to provide compatibility with
      # code using libstorage directly.
      # Remove once we adapt everything to the new API. So far
      # DiskAnalyzer is only used in the proposal (already adapted) and
      # yast-country (pending)
      # @deprecated
      @devicegraph = Devicegraph.new(devicegraph) if devicegraph.is_a?(Storage::Devicegraph)
    end

    # Partitions that can be used as EFI system partitions.
    #
    # Checks for the partition id to return all potential partitions.
    # Checking for content_info.efi? would only detect partitions that are
    # going to be effectively used.
    #
    # @see #scope
    #
    # @return [Hash{String => Array<Partition>}] see {#partitions_with_id}
    def efi_partitions(*disks)
      data_for(*disks, :efi_partitions) { |d| partitions_with_id(d, PartitionId::ESP) }
    end

    # Partitions that can be used as PReP partition
    # @see #scope
    #
    # @return [Hash{String => Array<Partition>}] see {#partitions_with_id}
    def prep_partitions(*disks)
      data_for(*disks, :prep_partitions) { |d| partitions_with_id(d, PartitionId::PREP) }
    end

    # GRUB (gpt_bios) partitions
    # @see #scope
    #
    # @return [Hash{String => Array<Partition>}] see {#partitions_with_id}
    def grub_partitions(*disks)
      data_for(*disks, :grup_partitions) { |d| partitions_with_id(d, PartitionId::BIOS_BOOT) }
    end

    # Partitions that can be used as swap space
    # @see #scope
    #
    # @return [Hash{String => Array<Partition>}] see {#partitions_with_id}
    def swap_partitions(*disks)
      data_for(*disks, :swap_partitions) { |d| partitions_with_id(d, PartitionId::SWAP) }
    end

    # Linux partitions. This may be a normal Linux partition (type 0x83), a
    # Linux swap partition (type 0x82), an LVM partition, or a RAID partition.
    # @see #scope
    #
    # @return [Hash{String => Array<Partition>}] see {#partitions_with_id}
    def linux_partitions(*disks)
      data_for(*disks, :linux_partitions) { |d| partitions_with_id(d, LINUX_PARTITION_IDS) }
    end

    # Partitions that are part of a LVM volume group, i.e. partitions that hold
    # a LVM physical volume.
    #
    # The result is a Hash in which each key is the name of a volume group
    # and the value is an Array of Partition objects
    #
    # Take into account that the result is, as always, limited by #scope. Thus,
    # physical volumes from other disks will not be present, even if they are
    # part of the same volume group.
    #
    # @return [Hash{String => Array<Partition>}]
    def used_lvm_partitions(*disks)
      data_for(*disks, :used_lvm_partitions) { |d| find_used_lvm_partitions(d) }
    end

    # MBR gap (size between MBR and first partition) for every disk.
    #
    # If there are no partitions or if the existing partition table is not
    # MBR-based the MBR gap is nil, meaning "gap not applicable" which is
    # different from "no gap" (i.e. a 0 bytes gap).
    #
    # @see #scope
    #
    # @return [Hash{String => (Y2Storage::DiskSize, nil)}] each key is the name
    # of a disk, the value is the DiskSize of the MBR gap (or nil)
    def mbr_gaps(*disks)
      data_for(*disks, :mbr_gap) { |d| find_mbr_gap(d) }
    end

    def mbr_gap(disk)
      mbr_gaps(disk).first
    end

    # Partitions containing an installation of MS Windows
    #
    # This involves mounting any Windows-like partition to check if there are
    # some typical directories (/windows/system32).
    #
    # @see #scope
    #
    # @return [Hash{String => Array<Partition>}] see {#partitions_with_id}
    def windows_partitions(*disks, limit: DEFAULT_DISKS_LIMIT)
      data_for(*disks, :windows_partitions, limit: limit) { |d| find_windows_partitions(d) }
    end

    # Disks that are suitable for installing Linux.
    #
    # @return [Array<Storage::Disk>] candidate disks
    def candidate_disks(limit: DEFAULT_DISKS_LIMIT)
      return @candidate_disks if @candidate_disks
      @candidate_disks = find_candidate_disks(limit)
      log.info("Found candidate disks: #{@candidate_disks}")
      @candidate_disks
    end

    def partition_in_vg?(partition, vg = nil)
      p_vg = partition_vg(partition)
      return false unless p_vg
      return true unless vg
      p_vg == vg
    end

    def partition_pv(partition)
      devicegraph.lvm_pvs.detect { |pv| pv.plain_blk_device == partition }
    end

    def partition_vg(partition)
      pv = partition_pv(partition)
      return nil unless pv
      pv.lvm_vg
    end

    # Look up devicegraph element by device name.
    #
    # @return [Device]
    def device_by_name(name)
      Disk.find_by_name(devicegraph, name)
    end

  private

    attr_reader :devicegraph

    def data_for(*disks, data, limit: nil)
      @disks_data ||= {}
      @disks_data[data] ||= {}
      disks = disks_collection(disks, limit)
      disks.each do |disk|
        @disks_data[data][disk.name] ||= yield(disk)
      end
      disks.map { |d| @disks_data[data][d.name] }.flatten.compact
    end

    def disks_collection(disks, limit = nil)
      disks = devicegraph.disks if disks.empty?
      disks = disks.first(limit) if limit
      disks = disks.map { |d| d.is_a?(String) ? Disk.find_by_name(devicegraph, d) : d }
      disks.compact
    end

    # Find partitions from any of the candidate disks that have a given (set
    # of) partition id(s).
    #
    # The result is a Hash in which each key is the name of a disk
    # and the value is an Array of Partition objects
    # representing the matching partitions in that disk.
    #
    # @param ids [PartitionId, Array<PartitionId>]
    # @param log_label [String] label to identify the partitions in the logs
    # @return [Hash{String => Array<Partition>}]
    def partitions_with_id(disk, ids)
      partitions = disk.partitions.reject { |p| p.type.is?(:extended) }
      partitions.select { |p| p.id.is?(*ids) }
    end

    def find_used_lvm_partitions(disk)
      partitions = partitions_with_id(disk, PartitionId::LVM)
      partitions.select { |p| partition_in_vg?(p) }
    end

    # @see #mbr_gap
    def find_mbr_gap(disk)
      return nil unless disk.partition_table
      return nil unless disk.partition_table.type.is?(:msdos)
      region1 = disk.partitions.min { |x, y| x.region.start <=> y.region.start }
      region1 ? region1.region.block_size * region1.region.start : nil
    end

    # @see #windows_partitions
    def find_windows_partitions(disk)
      return nil unless windows_architecture?
      possible_windows_partitions(disk).select { |p| windows_partition?(p) }
    end

    # Checks whether the architecture of the system is supported by
    # MS Windows
    #
    # @return [Boolean]
    def windows_architecture?
      # Should we include ARM here?
      Yast::Arch.x86_64 || Yast::Arch.i386
    end

    # Partitions that could potentially contain a MS Windows installation
    #
    # @param disk_name [String] name of the disk to check
    # @return [DevicesLists::PartitionsList]
    def possible_windows_partitions(disk)
      disk.partitions.select { |p| p.type.is?(:primary) && p.id.is?(*WINDOWS_PARTITION_IDS) }
    end

    # Check if device name 'partition' is a MS Windows partition that could
    # possibly be resized.
    #
    # @param partition [Partition] partition to check
    #
    # @return [Boolean] 'true' if it is a Windows partition, 'false' if not.
    #
    def windows_partition?(partition)
      log.info("Checking if #{partition.name} is a windows partition")
      filesystem = partition.filesystem
      is_win = filesystem && filesystem.detect_content_info.windows?

      log.info("#{partition.name} is a windows partition") if is_win
      is_win
    end

    # Find disks that are suitable for installing Linux.
    # Put any USB disks to the end of that array.
    #
    # @return [Array<Disk>] candidate disks
    def find_candidate_disks(limit)
      @installation_disks = find_installation_disks(limit)

      usb_disks, non_usb_disks = devicegraph.disks.partition { |d| d.usb? }

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

    # Find disks that look like the current installation medium
    # (the medium we just booted from to start the installation).
    #
    # This is limited with DiskAnalyzer::disk_check_limit because some
    # architectures (s/390) tend to have a large number of disks, and
    # checking if a disk is an installation disk involves mounting and
    # unmounting each partition on that disk.
    #
    # @return [Array<String>] device names of installation disks
    #
    def find_installation_disks(limit)
      usb_disks, non_usb_disks = devicegraph.disks.partition { |d| d.usb? }
      disks = usb_disks + non_usb_disks
      disks = disks.first(limit)
      disks.select { |d| installation_disk?(d) }
    end

    # Check if a disk is our installation disk - the medium we just booted
    # and started the installation from. This will check all filesystems on
    # that disk.
    #
    # @param disk_name [Storage::Disk] device to check
    #
    # @return [Boolean] 'true' if the disk is an installation disk
    #
    def installation_disk?(disk)
      log.info("Checking if #{disk.name} is an installation disk")
      # disk = device_by_name(disk.name)

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
    # @param vol_name [string] device name of the volume to check
    #
    # @return [Boolean] 'true' if the volume is an installation volume
    #
    def installation_volume?(device)
      log.info("Checking if #{device.name} is an installation volume")
      fs = ExistingFilesystem.new(device.name)
      is_inst = fs.mount_and_check { |mp| installation_volume_check(mp) }
      log.info("#{device.name} is installation volume") if is_inst
      is_inst
    end

    # Check if the volume mounted at 'mount_point' is an installation volume.
    # This is a separate method so it can be redefined in unit tests.
    #
    # @return [Boolean] 'true' if it is an installation volume, 'false' if not.
    #
    def installation_volume_check(mount_point)
      check_file = "/control.xml"
      if !File.exist?(check_file)
        log.error("ERROR: Check file #{check_file} does not exist in inst-sys")
        return false
      end
      mount_point += "/" unless mount_point.end_with?("/")
      return false unless File.exist?(mount_point + check_file)
      FileUtils.identical?(check_file, mount_point + check_file)
    end

    # Remove any installation disks from 'disks' and return a disks array
    # containing the disks that are not installation media.
    #
    # @param disks [Array<::Storage::Disk>]
    # @return [Array<::Storage::Disk>] non-installation disks
    #
    def remove_installation_disks(disks)
      # We can't simply use
      #   disks -= @installation_disks
      # because the list elements (from libstorage) don't provide a .hash method.
      # Comparing device names ("/dev/sda"...) instead.
      disks.delete_if { |disk| @installation_disks.map(&:name).include?(disk.name) }
    end
  end
end
