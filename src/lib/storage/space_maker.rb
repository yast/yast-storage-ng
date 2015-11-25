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
    # Class to provide free space for creating new partitions - either by
    # reusing existing unpartitioned space, by deleting existing partitions
    # or by resizing an existing Windows partiton.
    #
    class SpaceMaker
      include Yast::Logger

      attr_reader :volumes

      # Initialize.
      # @param volumes [list of ProposalVolume] volumes to find space for.
      # The volumes might be changed by this class.
      #
      # @param settings [Storage::Settings] parameters to use
      #
      def initialize(volumes, settings)
        @volumes  = volumes
        @settings = settings
        @disks    = candidate_disks
      end

      # Try to detect empty (unpartitioned) space.
      def find_space
        # TO DO
      end

      # Use force to create space: Try to resize an existing Windows
      # partition or delete partitions until there is enough free space.
      def make_space
        # TO DO
      end

      # Find disks that are suitable for installing Linux.
      # Put any USB disks to the end of that array.
      #
      # @return [Array<::Storage::Disk>] disks
      #
      def candidate_disks
        disks = ::Storage::Disk.all(StorageManager.instance.probed).to_a
        # FIXME: to_a should not be necessary:
        # libstorage should return something that Ruby can handle.
        # This is very likely a problem of the Swig bindings.

        usb_disks = disks.select { |disk| disk.transport == ::Storage::USB }
        usb_disks.each { |disk| log.info("Found USB disk #{disk}\n") }

        # Put USB disks to the back of the disks array:
        # Non-USB disks should get higher priority to install on
        disks -= usb_disks # Remove all USB disks from disks
        disks += usb_disks # Add USB disks at the end of disks
        installation_disks = []

        disks.each do |disk|
          print("Found disk #{disk}\n")
          if installation_disk?(disk)
            installation_disks << disk
            print("#{disk} is current installation disk\n")
          end
        end

        # We don't want to install on our installation disk if there is any other way.
        candidates = disks - installation_disks

        if candidates.empty?
          log.info("No candidate disks left after eliminating installation disks")
          log.info("Trying with non-USB installation disks")
          candidates = installation_disks.select { |disk| disk.transport != ::Storage::USB }
        end
        if candidates.empty?
          log.info("Still no candidate disks left")
          log.info("Trying with installation disks out of sheer desperation")
          candidates = installation_disks
        end

        candidate_names = candidates.map { |disk| disk.to_s }
        log.info("Candidate disks: #{candidate_names}")
        candidates
      end

      # Check if there are any Linux partitions on any of the disks.
      # This may be a normal Linux partition (type 0x83), a Linux swap
      # partition (type 0x82), an LVM partition, or a RAID partition.
      def linux_partitions?
        linux_partition_ids =
          [
            ::Storage::ID_LINUX,
            ::Storage::ID_SWAP,
            ::Storage::ID_LVM,
            ::Storage::ID_RAID
          ]

        @disks.each do |disk|
          begin
            disk.partition_table.partitions.each do |partition|
              if linux_partition_ids.include?(partition.id)
                log.info("Found Linux partition #{partition} (ID 0x#{partition.id.to_s(16)})")
                return true
              end
            end
          rescue RuntimeError => ex
            log.info("CAUGHT exception #{ex}")
          end
        end
        false
      end

      # Find any MS Windows partitions that could possibly be resized.
      #
      # @return [Array <Storage::partition>]
      #
      def find_windows_partitions
        windows_partitions = []
        windows_partition_ids =
          [
            ::Storage::ID_NTFS,
            ::Storage::ID_DOS32,
            ::Storage::ID_DOS16,
            ::Storage::ID_DOS12
          ]

        @disks.each do |disk|
          begin
            disk.partition_table.partitions.each do |partition|
              if windows_partition_ids.include?(partition.id)
                windows_partitions << partition if windows_partition?(partition)
              end
            end
          rescue RuntimeError => ex
            log.info("CAUGHT exception #{ex}")
          end
        end
        win_part_names = windows_partitions.map { |p| p.to_s }
        log.info("Windows partitions: #{win_part_names}")
        windows_partitions
      end

      # Check if 'partition' is a MS Windows partition that could possibly be
      # resized.
      #
      # @return [bool] 'true' if it is a Windows partition, 'false' if not.
      #
      def windows_partition?(partition)
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

      # Resize an existing MS Windows partition to free up disk space.
      def resize_windows_partition(partition)
        # TO DO
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
        check_file = "/control.xml"
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
          return false unless vol.filesystem
          mount(vol.name, mount_point)
          log.info("Checking vol #{vol}")
          check_result = block.call(mount_point)
          umount(vol.name)
          check_result
        rescue RuntimeError => ex
          log.error("CAUGHT exception: #{ex} for #{vol}")
          nil
        end
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
      def umount(device)
        # FIXME: use libstorage function when available
        cmd = "/usr/bin/umount #{device}"
        log.info("Unmounting: #{cmd}")
        raise "umount failed for #{device}" unless system(cmd)
      end
    end
  end
end
