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
require "fileutils"
require "storage"
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

    DEFAULT_DISK_CHECK_LIMIT = 10

    # @return [Fixnum] Maximum number of disks to check with "expensive"
    #   operations.
    #
    # Prevents, for example, mounting every single disk when looking for the
    # installation one.
    # @see #find_installation_disks
    # This might be important on architectures that tend to have very many
    # disks (s390).
    attr_reader :disk_check_limit

    # @return [Symbol, nil] Scope to limit the searches
    #   - :install_candidates - check only in #candidate_disks
    #   - nil - check all disks
    # @see #candidate_disks
    #
    # It affects all search methods like {#linux_partitions}, {#mbr_gap}, etc.
    attr_reader :scope

    def initialize(devicegraph, disk_check_limit: DEFAULT_DISK_CHECK_LIMIT, scope: nil)
      @devicegraph = devicegraph
      @disk_check_limit = disk_check_limit
      @scope = scope
      # FIXME: The following line is here just to provide compatibility with
      # code using libstorage directly.
      # Remove once we adapt everything to the new API. So far
      # DiskAnalyzer is only used in the proposal (already adapted) and
      # yast-country (pending)
      # @deprecated
      @devicegraph = Devicegraph.new(devicegraph) if devicegraph.is_a?(Storage::Devicegraph)
    end

    # Look up devicegraph element by device name.
    #
    # @return [Device]
    def device_by_name(name)
      Disk.find_by_name(devicegraph, name)
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
    def efi_partitions
      @efi_partitions ||= partitions_with_id(PartitionId::ESP, "EFI")
    end

    # Partitions that can be used as PReP partition
    # @see #scope
    #
    # @return [Hash{String => Array<Partition>}] see {#partitions_with_id}
    def prep_partitions
      @prep_partitions ||= partitions_with_id(PartitionId::PREP, "PReP")
    end

    # GRUB (gpt_bios) partitions
    # @see #scope
    #
    # @return [Hash{String => Array<Partition>}] see {#partitions_with_id}
    def grub_partitions
      @grub_partitions ||= partitions_with_id(PartitionId::BIOS_BOOT, "GRUB")
    end

    # Partitions that can be used as swap space
    # @see #scope
    #
    # @return [Hash{String => Array<Partition>}] see {#partitions_with_id}
    def swap_partitions
      @swap_partitions ||= partitions_with_id(PartitionId::SWAP, "Swap")
    end

    # Linux partitions. This may be a normal Linux partition (type 0x83), a
    # Linux swap partition (type 0x82), an LVM partition, or a RAID partition.
    # @see #scope
    #
    # @return [Hash{String => Array<Partition>}] see {#partitions_with_id}
    def linux_partitions
      @linux_partitions ||= partitions_with_id(LINUX_PARTITION_IDS, "Linux")
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
    def used_lvm_partitions
      @used_lvm_partitions ||= begin
        lvm_parts = partitions_with_id(PartitionId::LVM, "LVM").values.flatten
        result = lvm_parts.each_with_object({}) do |part, hash|
          vg_name = vg_for(part)
          next unless vg_name

          hash[vg_name] ||= []
          hash[vg_name] << part
        end
        log.info("Found used LVM partitions: #{result}")
        result
      end
    end

    # Disks that are suitable for installing Linux.
    #
    # @return [Array<String>] device names of candidate disks
    def candidate_disks
      @candidate_disks ||= begin
        @installation_disks = find_installation_disks
        result = dev_names(candidate_disk_objects)
        log.info("Found candidate disks: #{result}")
        result
      end
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
    def mbr_gap
      @mbr_gap ||= begin
        result = find_mbr_gap
        log.info("Found MBR gaps: #{result}")
        result
      end
    end

    # Partitions containing an installation of MS Windows
    #
    # This involves mounting any Windows-like partition to check if there are
    # some typical directories (/windows/system32).
    #
    # @see #scope
    #
    # @return [Hash{String => Array<Partition>}] see {#partitions_with_id}
    def windows_partitions
      @windows_partitions ||= begin
        result = find_windows_partitions
        log.info("Found Windows partitions: #{result}")
        result
      end
    end

  private

    attr_reader :devicegraph

    # Set of disks to be used in most search operations
    #
    # @return [Array<String>]
    def scoped_disks
      @scoped_disks ||= scope == :install_candidates ? candidate_disks : dev_names(all_disks)
    end

    # Array with all disks in the devicegraph
    #
    # @return [Array<Disk>]
    def all_disks
      devicegraph.disks
    end

    # List of disks in the devicegraph
    #
    # @return [DisksList]
    def disks
      devicegraph.disks
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
    def find_installation_disks
      usb_disks, non_usb_disks = all_disks.partition { |d| d.usb? }
      disks = usb_disks + non_usb_disks

      if disks.size > @disk_check_limit
        disks = disks.first(@disk_check_limit)
        log.info("Installation disk check limit exceeded - only checking #{dev_names(disks)}")
      end

      dev_names(disks.select { |disk| installation_disk?(disk.name) })
    end

    # Disks that are suitable for installing Linux.
    # Put any USB disks to the end of that array.
    #
    # @return [Array<Disk>] device names of candidate disks
    def candidate_disk_objects
      usb_disks, non_usb_disks = all_disks.partition { |d| d.usb? }
      log.info("USB Disks:     #{dev_names(usb_disks)}")
      log.info("Non-USB Disks: #{dev_names(non_usb_disks)}")

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

    # @see #mbr_gap
    def find_mbr_gap
      gaps = {}
      scoped_disks.each do |name|
        disk = device_by_name(name)
        gap = nil
        if disk.partition_table && disk.partition_table.type.is?(:msdos)
          region1 = disk.partitions.min do |x, y|
            x.region.start <=> y.region.start
          end
          gap = region1.region.block_size * region1.region.start if region1
        end
        gaps[name] = gap
      end
      gaps
    end

    # @see #windows_partitions
    def find_windows_partitions
      return {} unless windows_architecture?
      windows_partitions = {}

      # No need to limit checking - PC arch only (few disks)
      scoped_disks.each do |disk_name|
        windows_partitions[disk_name] = []
        possible_windows_partitions(disk_name).each do |partition|
          windows_partitions[disk_name] << partition if windows_partition?(partition)
        end
      end
      windows_partitions
    end

    # Checks whether the architecture of the system is supported by
    # MS Windows
    #
    # @return [Boolean]
    def windows_architecture?
      # Should we include ARM here?
      Yast::Arch.x86_64 || Yast::Arch.i386
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
      filesystem = filesystem_for(partition)
      is_win = filesystem && filesystem.detect_content_info.windows?

      log.info("#{partition.name} is a windows partition") if is_win
      !!is_win
    end

    # Partitions that could potentially contain a MS Windows installation
    #
    # @param disk_name [String] name of the disk to check
    # @return [DevicesLists::PartitionsList]
    def possible_windows_partitions(disk_name)
      devicegraph.partitions.select do |p|
        p.disk.name == disk_name && p.type.is?(:primary) && p.id.is?(*WINDOWS_PARTITION_IDS)
      end
    end

    # Filesystem associated to a given block device
    #
    # @param blk_device [Storage::BlkDevice] device that could be formatted
    # @return [Storage::BlkFilesystem] filesystem object or nil of
    def filesystem_for(blk_device)
      blk_device.filesystem
    rescue Storage::Exception
      nil
    end

    # Check if a disk is our installation disk - the medium we just booted
    # and started the installation from. This will check all filesystems on
    # that disk.
    #
    # @param disk_name [string] device name of the disk to check
    #
    # @return [Boolean] 'true' if the disk is an installation disk
    #
    def installation_disk?(disk_name)
      log.info("Checking if #{disk_name} is an installation disk")
      disk = device_by_name(disk_name)

      # Check if there is a filesystem directly on the disk (without partition table).
      # This is very common for installation media such as USB sticks.
      return installation_volume?(disk_name) if disk.partition_table.nil?

      disk.partitions.each do |partition|
        if NO_INSTALLATION_IDS.include?(partition.id)
          log.info "Skipping #{partition} (ID #{partition.id.inspect})"
          next
        elsif installation_volume?(partition.name)
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
    def installation_volume?(vol_name)
      log.info("Checking if #{vol_name} is an installation volume")
      fs = ExistingFilesystem.new(vol_name)
      is_inst = fs.mount_and_check { |mp| installation_volume_check(mp) }
      log.info("#{vol_name} is installation volume") if is_inst
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

    # Return an array of the device names of the specified block devices
    # (::Storage::Disk, ::Storage::Partition, ...).
    #
    # @param blk_devices [Array<BlkDev>]
    # @return [Array<String>] names, e.g. ["/dev/sda", "/dev/sdb1", "/dev/sdc3"]
    #
    def dev_names(blk_devices)
      blk_devices.map(&:name)
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

      disks.delete_if { |disk| @installation_disks.include?(disk.name) }
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
    def partitions_with_id(ids, log_label)
      pairs = scoped_disks.map do |disk_name|
        # Skip extended partitions
        partitions = device_by_name(disk_name).partitions.reject do |part|
          part.type.is?(:extended)
        end
        partitions.select! { |p| p.id.is?(*ids) }
        [disk_name, partitions]
      end
      result = Hash[pairs]
      log.info("Found #{log_label} partitions: #{result}")
      result
    end

    # Name of the LVM volume group to which the partition belongs
    #
    # @param partition [Partition]
    # @return [String] nil if the partition does not hold a physical volume
    def vg_for(partition)
      name = partition.name
      lvm_pv = LvmPv.all(devicegraph).detect { |pv| pv.blk_device.name == name }
      return nil unless lvm_pv

      # Unassigned PV
      return nil if lvm_pv.lvm_vg.nil?

      lvm_pv.lvm_vg.vg_name
    end
  end
end
