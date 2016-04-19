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
require "storage/disk_size"
require "storage/refinements/disk"
require "storage/refinements/devicegraph_lists"

module Yast
  module Storage
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
      using Refinements::Disk
      using Refinements::DevicegraphLists

      LINUX_PARTITION_IDS =
        [
          ::Storage::ID_LINUX,
          ::Storage::ID_SWAP,
          ::Storage::ID_LVM,
          ::Storage::ID_RAID
        ]

      WINDOWS_PARTITION_IDS =
        [
          ::Storage::ID_NTFS,
          ::Storage::ID_DOS32,
          ::Storage::ID_DOS16,
          ::Storage::ID_DOS12
        ]

      NO_INSTALLATION_IDS =
        [
          ::Storage::ID_SWAP,
          ::Storage::ID_EXTENDED,
          ::Storage::ID_LVM
        ]

      DEFAULT_DISK_CHECK_LIMIT = 10

      # @return [Array<String>] device names of installation media.
      #       Filled by #analyze.
      attr_reader :installation_disks

      # @return [Array<String>] device name of disks to install on.
      #       Filled by #analyze.
      attr_reader :candidate_disks

      # @return [Hash{String => Array<::Storage::Partition>}] Linux
      #     partitions found in each candidate disk. Filled by #analyze.
      #     @see #find_linux_partitions
      attr_reader :linux_partitions

      # @return [Hash{String => Array<::Storage::Partition>}] MS Windows
      #     partitions found in each candidate disk.
      #     Filled by #analyze only if #linux_partitions is empty.
      #     @see #find_windows_partitions
      attr_reader :windows_partitions

      # @return [Hash{String => Array<::Storage::Partition>}] EFI partitions
      #     found in each candidate disk. Filled by #analyze.
      #     @see #find_efi_partitions
      attr_reader :efi_partitions

      # @return [Hash{String => Array<::Storage::Partition>}] PReP partitions
      #     found in each candidate disk. Filled by #analyze.
      #     @see #find_prep_partitions
      attr_reader :prep_partitions

      # @return [Hash{String => Array<::Storage::Partition>}] GRUB partitions
      #     found in each candidate disk. Filled by #analyze.
      #     @see #find_grub_partitions
      attr_reader :grub_partitions

      # @return [Hash{String => Array<::Storage::Partition>}] Swap partitions
      #     found in each candidate disk. Filled by #analyze.
      #     @see #find_swap_partitions
      attr_reader :swap_partitions

      # @return [Hash{String => Array<Yast::Storage::DiskSize>}] MBR gap sizes
      #     found on each candidate disk. Filled by #analyze.
      #     @see #find_mbr_gap
      attr_reader :mbr_gap

      # @return [Fixnum] Maximum number of disks to check.
      #     @see #find_installation_disks
      attr_accessor :disk_check_limit

      def initialize
        Yast.import "Arch"

        @installation_disks = []
        @candidate_disks    = []
        @linux_partitions   = {}
        @windows_partitions = {}
        @efi_partitions     = {}
        @prep_partitions    = {}
        @grub_partitions    = {}
        @swap_partitions    = {}
        @mbr_gap            = {}

        # Maximum number of disks to check. This might be important on
        # architectures that tend to have very many disks (s390).
        @disk_check_limit = DEFAULT_DISK_CHECK_LIMIT
      end

      # Analyze disks and partitions. Make sure to call this before querying
      # any member variables.
      #
      def analyze(devicegraph)
        @devicegraph = devicegraph

        @installation_disks = find_installation_disks
        @candidate_disks    = find_candidate_disks
        @linux_partitions   = find_linux_partitions
        @efi_partitions     = find_efi_partitions
        @prep_partitions    = find_prep_partitions
        @grub_partitions    = find_grub_partitions
        @swap_partitions    = find_swap_partitions
        @mbr_gap            = find_mbr_gap

        if @linux_partitions.empty?
          @windows_partitions = find_windows_partitions
        else
          # We only want to resize any MS Windows partition if there is no
          # Linux already on that machine, so we don't need to check for
          # Windows partitions in that case. This saves mounting and unmounting
          # all Windows-like partitions.
          log.info("Linux partitions found - not checking for Windows partitions")
        end

        log.info("Installation disks: #{@installation_disks}")
        log.info("Candidate    disks: #{@candidate_disks}")
        log.info("Linux   partitions: #{@linux_partitions}")
        log.info("Windows partitions: #{@windows_partitions}")
        log.info("EFI     partitions: #{@efi_partitions}")
        log.info("PReP    partitions: #{@prep_partitions}")
        log.info("GRUB    partitions: #{@grub_partitions}")
        log.info("Swap    partitions: #{@swap_partitions}")
        log.info("MBR gap: #{@mbr_gap}")
      end

      # Look up devicegraph element by device name.
      #
      # @return [<::Storage::Device}>]
      def device_by_name(name)
        devicegraph.disks.with(name: name).first
      end

    private

      attr_reader :devicegraph

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

      # Find disks that are suitable for installing Linux.
      # @see #candidate_disks
      #
      # @return [Array<string>] device names of candidate disks
      #
      def find_candidate_disks
        dev_names(candidate_disk_objects)
      end

      # Array with all disks in the devicegraph
      #
      # @return [Array<::Storage::Disk>]
      def all_disks
        devicegraph.all_disks.to_a
      end

      # List of disks in the devicegraph
      #
      # @return [DisksList]
      def disks
        devicegraph.disks
      end

      # Disks that are suitable for installing Linux.
      # Put any USB disks to the end of that array.
      #
      # @return [Array<::Storage::Disk>] device names of candidate disks
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

      # Find partitions from any of the candidate disks that can be used as
      # PReP partition
      #
      # @return [Hash{String => Array<::Storage::Partition>}] @see #partitions_by_id
      def find_prep_partitions
        partitions_with_id(::Storage::ID_PPC_PREP)
      end

      # Find partitions from any of the candidate disks that can be used as
      # GRUB partition
      #
      # @return [Hash{String => Array<::Storage::Partition>}] @see #partitions_by_id
      def find_grub_partitions
        partitions_with_id(::Storage::ID_GPT_BIOS)
      end

      # Find partitions from any of the candidate disks that can be used as
      # swap space
      #
      # @return [Hash{String => Array<::Storage::Partition>}] @see #partitions_by_id
      def find_swap_partitions
        partitions_with_id(::Storage::ID_SWAP)
      end

      # Find any Linux partitions on any of the candidate disks.
      # This may be a normal Linux partition (type 0x83), a Linux swap
      # partition (type 0x82), an LVM partition, or a RAID partition.
      #
      # @return [Hash{String => Array<::Storage::Partition>}] @see #partitions_by_id
      def find_linux_partitions
        partitions_with_id(LINUX_PARTITION_IDS)
      end

      # Determine MBR gap (size between MBR and first partition) for all candidate disks.
      #
      # The result is a Hash in which each key is the name of a candidate disk
      # and the value is the DiskSize of the MBR gap.
      #
      # Note: the gap sizes on non-DOS partition tables are 0 (by definition).
      #
      # FIXME: sizes in Region are more or less useless atm, Arvin will fix this.
      # If that's done switch from kb to byte units.
      #
      # @return [Hash{String => Array<Yast::Storage::DiskSize>}]
      def find_mbr_gap
        gaps = {}
        candidate_disks.each do |name|
          disk = device_by_name(name)
          gap = DiskSize.kiB(0)
          if disk.partition_table? && disk.partition_table.type == ::Storage::PtType_MSDOS
            region1 = (disk.partition_table.partitions.to_a.min do |x, y|
              x.region.to_kb(x.region.start) <=> y.region.to_kb(y.region.start)
            end).region
            gap = DiskSize.kiB(region1.to_kb(region1.start))
          end
          gaps[name] = gap
        end
        gaps
      end

      # Find any MS Windows partitions that could possibly be resized.
      #
      # This involves mounting any Windows-like partition to check if there are
      # some typical directories (/windows/system32).
      #
      # Notice that by default this is not called if any Linux partitions were
      # found on any of the candidate disks (i.e., on any disk except the
      # installation medium). This can be called independently from the
      # outside, though.
      #
      # @return [Array <::Storage::Partition>]
      #
      def find_windows_partitions
        return [] unless Arch.x86_64 || Arch.i386
        windows_partitions = {}

        # No need to limit checking - PC arch only (few disks)
        @candidate_disks.each do |disk_name|
          begin
            disk = ::Storage::Disk.find(devicegraph, disk_name)
            disk.partition_table.partitions.each do |partition|
              next unless windows_partition?(partition)

              windows_partitions[disk_name] ||= []
              windows_partitions[disk_name] << partition
            end
          rescue RuntimeError => ex  # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
            log.info("CAUGHT exception #{ex}")
          end
        end
        windows_partitions
      end

      # Check if device name 'partition' is a MS Windows partition that could
      # possibly be resized.
      #
      # @param partition [string| device name of the partition to check
      #
      # @return [Boolean] 'true' if it is a Windows partition, 'false' if not.
      #
      def windows_partition?(partition)
        return false unless WINDOWS_PARTITION_IDS.include?(partition.id)
        return false unless Arch.x86_64 || Arch.i386
        log.info("Checking if #{partition.name} is a windows partition")
        is_win = mount_and_check(partition) { |mp| windows_partition_check(mp) }
        log.info("#{partition} is a windows partition") if is_win
        is_win
      end

      # Check if the volume mounted at 'mount_point' is a Windows partition
      # that could be resized.
      #
      # This is a separate method so it can be redefined in unit tests.
      #
      # @return [Boolean] 'true' if it is a Windows partition, 'false' if not.
      #
      def windows_partition_check(mount_point)
        Dir.exist?(mount_point + "/windows/system32")
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
        begin
          disk = ::Storage::Disk.find(devicegraph, disk_name)
          disk.partition_table.partitions.each do |partition|
            if NO_INSTALLATION_IDS.include?(partition.id)
              log.info("Skipping #{partition} (ID 0x#{partition.id.to_s(16)})")
              next
            else
              return true if installation_volume?(partition.name)
            end
          end
          return false # if we get here, there is a partition table.
        rescue RuntimeError => ex  # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
          log.info("CAUGHT exception: #{ex} for #{disk}")
        end

        # Check if there is a filesystem directly on the disk (without partition table).
        # This is very common for installation media such as USB sticks.
        installation_volume?(disk_name)
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
        is_inst = mount_and_check(vol_name) { |mp| installation_volume_check(mp) }
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

      # Mount a volume, perform the check given in 'block' while mounted, and
      # then unmount. The block will get the mount point of the volume as a
      # parameter.
      #
      # @return the return value of 'block' or 'nil' if there was an error.
      #
      def mount_and_check(vol_name, &block)
        raise ArgumentError, "Code block required" unless block_given?
        mount_point = "/mnt" # FIXME
        begin
          # check if we have a filesystem
          # return false unless vol.filesystem
          mount(vol_name, mount_point)
          check_result = block.call(mount_point)
          umount(mount_point)
          check_result
        rescue RuntimeError => ex  # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
          log.error("CAUGHT exception: #{ex} for #{vol_name}")
          nil
        end
      end

      # Return an array of the device names of the specified block devices
      # (::Storage::Disk, ::Storage::Partition, ...).
      #
      # @param blk_devices [Array<BlkDev>]
      # @return [Array<string>] names, e.g. ["/dev/sda", "/dev/sdb1", "/dev/sdc3"]
      #
      def dev_names(blk_devices)
        blk_devices.map(&:to_s)
      end

      # Mount a device.
      #
      # This is a temporary workaround until the new libstorage can handle that.
      #
      def mount(device_name, mount_point)
        # FIXME: use libstorage function when available
        cmd = "/usr/bin/mount #{device_name} #{mount_point} >/dev/null 2>&1"
        log.debug("Trying to mount #{device_name}: #{cmd}")
        raise "mount failed for #{device_name}" unless system(cmd)
      end

      # Unmount a device.
      #
      # This is a temporary workaround until the new libstorage can handle that.
      #
      def umount(mount_point)
        # FIXME: use libstorage function when available
        cmd = "/usr/bin/umount #{mount_point}"
        log.debug("Unmounting: #{cmd}")
        raise "umount failed for #{mount_point}" unless system(cmd)
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
      # The result is a Hash in which each key is the name of a candidate disk
      # and the value is an Array of ::Storage::Partition objects
      # representing the matching partitions in that disk.
      #
      # @param ids [::Storage::ID, Array<::Storage::ID>]
      # @return [Hash{String => Array<::Storage::Partition>}]
      def partitions_with_id(ids)
        pairs = candidate_disks.map do |disk_name|
          # Skip extended partitions
          partitions = disks.with(name: disk_name).partitions.with do |part|
            part.type != ::Storage::PartitionType_EXTENDED
          end
          partitions = partitions.with(id: ids).to_a
          [disk_name, partitions]
        end
        Hash[pairs]
      end

      # Find partitions from any of the candidate disks that can be used as
      # EFI system partitions.
      #
      # Checks for the partition id to return all potential partitions.
      # Checking for content_info.efi? would only detect partitions that are
      # going to be effectively used.
      #
      # @return [Hash{String => Array<::Storage::Partition>}] @see #partitions_by_id
      def find_efi_partitions
        partitions_with_id(::Storage::ID_EFI)
      end
    end
  end
end
