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
        @disks    = nil
      end

      # Try to detect empty (unpartitioned) space.
      def find_space
        @disks ||= candidate_disks
      end

      # Use force to create space: Try to resize an existing Windows
      # partition or delete partitions until there is enough free space.
      def make_space
        @disks ||= candidate_disks
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
      end

      # Check if there is a MS Windows partition that could possibly be
      # resized.
      #
      # @return [bool] 'true# if there is a Windows partition, 'false' if not.
      def windows_partition?
        # TO DO
        false
      end

      # Resize an existing MS Windows partition to free up disk space.
      def resize_windows_partition
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
        rescue Exception => ex # No partition table on this disk
          log.info("CAUGHT exception: #{ex} for #{disk}")
        end

        # Check if there is a filesystem directly on the disk (without partition table).
        # This is very common for installation media such as USB sticks.
        return installation_volume?(disk)
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
        # check if we have a filesystem
        log.info("Checking if #{vol.name} is an installation volume")
        mount_point = "/mnt" # FIXME
        check_file = "/control.xml"
        begin
          return false unless vol.filesystem
          mount(vol.name, mount_point)

          log.info("Checking if vol #{vol} is an installation volume")
          return false unless File.exist?(mount_point + check_file)
          found_check_file = FileUtils.identical?(check_file, mount_point + check_file)
          log.info("#{vol} is installation medium (found identical #{check_file})") if found_check_file

          umount(vol.name)
          found_check_file
        rescue Exception => ex
          log.error("CAUGHT exception: #{ex} for #{vol}")
          false
        end
      end

      # Mount a device.
      #
      # This is a temporary workaround until the new libstorage can handle that.
      #
      def mount(device, mount_point)
        # FIXME use libstorage function when available
        cmd = "/usr/bin/mount -r #{device} #{mount_point} >/dev/null 2>&1"
        log.info("Trying to mount #{device}: #{cmd}")
        raise RuntimeError, "mount failed for #{device}" unless system(cmd)
      end

      # Unmount a device.
      #
      # This is a temporary workaround until the new libstorage can handle that.
      #
      def umount(device)
        # FIXME use libstorage function when available
        cmd = "/usr/bin/umount #{device}"
        log.info("Unmounting: #{cmd}")
        raise RuntimeError, "umount failed for #{device}" unless system(cmd)
      end
    end
  end
end
