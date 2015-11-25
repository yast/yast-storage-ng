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
require_relative "./proposal_volume"
require_relative "./disk_size"
require "pp"

module Yast
  module Storage
    #
    # Class to analyze the disks (the storage setup) of the existing system:
    # Check the existing disks and their partitions what candidates there are
    # to install on, typically eliminate the installation media from that list
    # (unless there is no other disk), check if there is a Windows partition
    # that could be resized, check if there already are any partitions that
    # look like there was a Linux system previously installed on that machine.
    #
    # Many of those operations involve trying to mount the underlying
    # filesystem.
    #
    class DiskAnalyzer
      include Yast::Logger

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

      DEFAULT_DISK_CHECK_LIMIT = 10

      attr_reader :installation_disks, :candidate_disks
      attr_reader :windows_partitions, :linux_partitions
      attr_accessor :disk_check_limit

      # Initialize.
      #
      # @param settings [Storage::Settings] parameters to use
      #
      def initialize
        Yast.import "Arch"

        @installation_disks = []
        @candidate_disks    = []
        @linux_partitions   = []
        @windows_partitions = [] # only filled if @linux_partitions is empty

        # Maximum number of disks to check. This might be important on
        # architectures that tend to have very many disks (s390).
        @disk_check_limit = DEFAULT_DISK_CHECK_LIMIT
      end

      # Analyze disks and partitions. Make sure to call this before querying
      # any member variables.
      #
      def analyze
        @installation_disks = find_installation_disks
        @candidate_disks    = find_candidate_disks
        @linux_partitions   = find_linux_partitions

        if @linux_partitions.empty?
          @windows_partitions = find_windows_partitions
        else
          # We only want to resize any MS Windows partition if there is no
          # Linux already on that machine, so we don't need to check for
          # Windows partitions in that case. This saves mounting and unmounting
          # all Windows-like partitions.
          log.info("Linux partitions found - not checking for Windows partitions")
        end

        log.info("Installation disks: #{dev_names(@installation_disks)}")
        log.info("Candidate    disks: #{dev_names(@candidate_disks)}")
        log.info("Linux   partitions: #{dev_names(@linux_partitions)}")
        log.info("Windows partitions: #{dev_names(@windows_partitions)}")
      end

      # Find disks that look like the current installation medium
      # (the medium we just booted from to start the installation).
      #
      # This is limited with DiskAnalyzer::disk_check_limit because some
      # architectures (s/390) tend to have a large number of disks, and
      # checking if a disk is an installation disk involves mounting and
      # unmounting each partition on that disk.
      #
      # @return [Array<::Storage::Disk>] disks
      #
      def find_installation_disks
        disks = ::Storage::Disk.all(StorageManager.instance.probed).to_a
        # FIXME: to_a should not be necessary:
        # libstorage should return something that Ruby can handle.
        # This is very likely a problem of the Swig bindings.

        usb_disks, non_usb_disks = disks.partition { |disk| disk.transport == ::Storage::USB }
        disks = usb_disks + non_usb_disks
        disk_count = 0
        installation_disks = []

        disks.each do |disk|
          installation_disks << disk if installation_disk?(disk)
          disk_count += 1
          if disk_count > @disk_check_limit
            log.info("Disk check limit reached after #{disk}")
            break
          end
        end
        installation_disks
      end

      # Find disks that are suitable for installing Linux.
      # Put any USB disks to the end of that array.
      #
      # @return [Array<::Storage::Disk>] disks
      #
      def find_candidate_disks
        disks = ::Storage::Disk.all(StorageManager.instance.probed).to_a
        # FIXME: to_a should not be necessary

        usb_disks, non_usb_disks = disks.partition { |disk| disk.transport == ::Storage::USB }
        log.info("USB Disks:     #{dev_names(usb_disks)}")
        log.info("Non-USB Disks: #{dev_names(non_usb_disks)}")

        # We don't want to install on our installation disk if there is any other way.
        candidate_disks = remove_installation_disks(non_usb_disks + usb_disks)
        if candidate_disks.empty?
          log.info("No candidate disks left after eliminating installation disks")
          log.info("Trying with non-USB installation disks")
          candidate_disks = @installation_disks.select { |disk| disk.transport != ::Storage::USB }
        end
        if candidate_disks.empty?
          log.info("Still no candidate disks left")
          log.info("Trying with installation disks out of sheer desperation")
          candidate_disks = @installation_disks
        end
        candidate_disks
      end

      # Remove any installation disks from 'disks' and return a disks array
      # containing the disks that are not installation media.
      #
      # @param disks [Array<::Storage::Disk>]
      # @return [Array<::Storage::Disk>] disks
      #
      def remove_installation_disks(disks)
        # We can't simply use
        #   disks -= @installation_disks
        # because the list elements (from libstorage) don't provide a .hash method.
        # Comparing device names ("/dev/sda"...) instead.
        
        inst_names = dev_names(@installation_disks)
        disks.delete_if { |disk| inst_names.include?(disk.name) }
      end

      # Find any Linux partitions on any of the candidate disks.
      # This may be a normal Linux partition (type 0x83), a Linux swap
      # partition (type 0x82), an LVM partition, or a RAID partition.
      #
      # @return [Array<Partition>] Linux partitions
      #
      def find_linux_partitions
        linux_partitions = []
        @candidate_disks.each do |disk|
          begin
            disk.partition_table.partitions.each do |partition|
              if LINUX_PARTITION_IDS.include?(partition.id)
                log.info("Found Linux partition #{partition} (ID 0x#{partition.id.to_s(16)})")
                linux_partitions << partition
              end
            end
          rescue RuntimeError => ex
            log.info("CAUGHT exception #{ex}")
          end
        end
        log.info("Linux part: #{dev_names(linux_partitions)}")
        linux_partitions
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
      # @return [Array <Storage::partition>]
      #
      def find_windows_partitions
        return [] unless Arch.x86_64 || Arch.i386
        windows_partitions = []

        # No need to limit checking - PC arch only (few disks)
        @candidate_disks.each do |disk|
          begin
            disk.partition_table.partitions.each do |partition|
              if WINDOWS_PARTITION_IDS.include?(partition.id)
                windows_partitions << partition if windows_partition?(partition)
              end
            end
          rescue RuntimeError => ex
            log.info("CAUGHT exception #{ex}")
          end
        end
        windows_partitions
      end

      # Check if 'partition' is a MS Windows partition that could possibly be
      # resized.
      #
      # @return [bool] 'true' if it is a Windows partition, 'false' if not.
      #
      def windows_partition?(partition)
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
      # @return 'true' if it is a Windows partition, 'false' if not.
      #
      def windows_partition_check(mount_point)
        Dir.exists?(mount_point + "/windows/system32")
      end

      # Check if a disk is our installation disk - the medium we just booted
      # and started the installation from. This will check all filesystems on
      # that disk.
      #
      def installation_disk?(disk)
        log.info("Checking if #{disk} is an installation disk")
        begin
          disk.partition_table.partitions.each do |partition|
            if [::Storage::ID_SWAP, ::Storage::ID_EXTENDED].include?(partition.id)
              log.info("Skipping #{partition} with partition type #{partition.id}")
              next
            else
              return true if installation_volume?(partition)
            end
          end
          return false # if we get here, there is a partition table.
        rescue RuntimeError => ex
          log.info("CAUGHT exception: #{ex} for #{disk}")
        end

        # Check if there is a filesystem directly on the disk (without partition table).
        # This is very common for installation media such as USB sticks.
        installation_volume?(disk)
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
      def installation_volume?(vol)
        log.info("Checking if #{vol.name} is an installation volume")
        is_inst = mount_and_check(vol) { |mp| installation_volume_check(mp) }
        log.info("#{vol} is installation medium") if is_inst
        is_inst
      end

      # Check if the volume mounted at 'mount_point' is an installation volume.
      # This is a separate method so it can be redefined in unit tests.
      #
      # @return 'true' if it is an installation volume, 'false' if not.
      #
      def installation_volume_check(mount_point)
        check_file = "control.xml" # FIXME: "/control.xml"
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
      def mount_and_check(vol, &block)
        raise ArgumentError, "Code block required" unless block_given?
        mount_point = "/mnt" # FIXME
        begin
          # check if we have a filesystem
          # return false unless vol.filesystem
          mount(vol.name, mount_point)
          check_result = block.call(mount_point)
          umount(mount_point)
          check_result
        rescue RuntimeError => ex
          log.error("CAUGHT exception: #{ex} for #{vol}")
          nil
        end
      end

      # Return an array of the device names of the specified block devices
      # (::Storage::Disk, ::Storage::Partition, ...).
      #
      # @param disks [Array<BlkDev>]
      # @return [Array<string>] names
      #
      def dev_names(blk_devices)
        blk_devices.map { |x| x.to_s }
      end

      # Mount a device.
      #
      # This is a temporary workaround until the new libstorage can handle that.
      #
      def mount(device, mount_point)
        # FIXME: use libstorage function when available
        cmd = "/usr/bin/mount #{device} #{mount_point} >/dev/null 2>&1"
        log.info("Trying to mount #{device}: #{cmd}")
        raise "mount failed for #{device}" unless system(cmd)
      end

      # Unmount a device.
      #
      # This is a temporary workaround until the new libstorage can handle that.
      #
      def umount(mount_point)
        # FIXME: use libstorage function when available
        cmd = "/usr/bin/umount #{mount_point}"
        log.info("Unmounting: #{cmd}")
        raise "umount failed for #{mount_point}" unless system(cmd)
      end
    end
  end
end
