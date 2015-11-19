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
require_relative "./disk_size"
require_relative "./storage_manager"
require "pp"

# This file can be invoked separately for minimal testing.
# Use 'sudo' if you do that since it will do hardware probing with libstorage.

module Yast
  module Storage
    #
    # Storage proposal for installation: Class that can suggest how to create
    # or change partitions for a Linux system installation based on available
    # storage devices (disks) and certain configuration parameters.
    #
    class Proposal
      include Yast::Logger

      # User-configurable settings for the storage proposal.
      # Those are settings the user can change in the UI.
      #
      class UserSettings
        attr_accessor :use_lvm, :encrypt_volume_group
        attr_accessor :root_filesystem_type, :use_snapshots
        attr_accessor :use_separate_home, :home_filesystem_type
        attr_accessor :enlarge_swap_for_suspend

        def initialize
          @use_lvm                  = false
          @encrypt_volume_group     = false
          @root_filesystem_type     = ::Storage::BTRFS
          @use_snapshots            = true
          @use_separate_home        = true
          @home_filesystem_type     = ::Storage::XFS
          @enlarge_swap_for_suspend = false
        end
      end

      # Per-product settings for the storage proposal.
      # Those settings are read from /control.xml on the installation media.
      # The user can directly override the part inherited from UserSettings.
      #
      class Settings < UserSettings
        attr_accessor :root_base_size
        attr_accessor :root_max_size
        attr_accessor :root_space_percent
        attr_accessor :btrfs_increase_percentage
        attr_accessor :limit_try_home
        attr_accessor :lvm_keep_unpartitioned_region
        attr_accessor :lvm_desired_size
        attr_accessor :lvm_home_max_size
        attr_accessor :btrfs_default_subvolume
        attr_accessor :home_min_size
        attr_accessor :home_max_size

        def initialize
          super
          # Default values taken from SLE-12-SP1
          @root_base_size                = DiskSize.GiB(3)
          @root_max_size                 = DiskSize.GiB(10)
          @root_space_percent            = 40
          @btrfs_increase_percentage     = 300.0
          @limit_try_home                = DiskSize.GiB(20)
          @lvm_keep_unpartitioned_region = false
          @lvm_desired_size              = DiskSize.GiB(15)
          @lvm_home_max_size             = DiskSize.GiB(25)
          @btrfs_default_subvolume       = "@"

          # Not yet in control.xml
          @home_min_size                 = DiskSize.GiB(10)
          @home_max_size                 = DiskSize.unlimited
        end

        def read_from_xml_file(xml_file_name)
          # TO DO
        end
      end

      # Class to represent a planned volume (partition or logical volume) and
      # its constraints
      #
      class Volume
        attr_accessor :mount_point, :filesystem_type
        attr_accessor :size, :min_size, :max_size, :desired_size
        attr_accessor :can_live_on_logical_volume, :logical_volume_name

        def initialize(mount_point, filesystem_type = nil)
          @mount_point = mount_point
          @filesystem_type = filesystem_type
          @size         = DiskSize.zero
          @min_size     = DiskSize.zero
          @max_size     = DiskSize.unlimited
          @desired_size = DiskSize.unlimited
          @can_live_on_logical_volume = false
          @logical_volume_name = nil

          return unless @mount_point.start_with?("/")
          return if @mount_point.start_with?("/boot")

          @can_live_on_logical_volume = true
          if @mount_point == "/"
            @logical_volume_name = "root"
          else
            @logical_volume_name = @mount_point.sub(%r{^/}, "")
          end
        end
      end

      # Class to provide free space for creating new partitions - either by
      # reusing existing unpartitioned space, by deleting existing partitions
      # or by resizing an existing Windows partiton.
      #
      class SpaceMaker
        attr_reader :volumes

        # Initialize.
        # @param volumes [list of Storage::Volume] volumes to find space for.
        # The volumes might be changed by this class.
        #
        # @param settings [Storage::Settings] parameters to use
        #
        def initialize(volumes, settings)
          @volumes  = volumes
          @settings = settings
          storage = StorageManager.instance
        end

        # Try to detect empty (unpartitioned) space.
        def find_space
        end

        # Use force to create space: Try to resize an existing Windows
        # partition or delete partitions until there is enough free space.
        def make_space
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
      end

      # Class that can check requirements for the different kinds of boot
      # partition: /boot, EFI-boot, PReP.
      #
      # TO DO: Check with arch maintainers if the requirements are correct.
      #
      class BootRequirementsChecker
        def initialize(settings)
          @settings = settings
        end

        def needed_partitions
          boot_volumes = []
          boot_volumes << make_efi_boot_partition if efi_boot_partition_needed?
          boot_volumes << make_boot_partition     if boot_partition_needed?
          boot_volumes << make_prep_partition     if prep_partition_needed?
          boot_volumes
        end

        def boot_partition_needed?
          return true if @settings.use_lvm && @settings.encrypt_volume_group
          false
        end

        def efi_boot_partition_needed?
          # TO DO
          false
        end

        def prep_partition_needed?
          # TO DO
          false
        end

        private

        def make_boot_partition
          vol = Volume.new("/boot", ::Storage::EXT4)
          vol.min_size = DiskSize.MiB(512) # TO DO
          vol.max_size = DiskSize.MiB(512) # TO DO
          vol.desired_size = vol.min_size
          vol.can_live_on_logical_volume = false
          vol
        end

        def make_efi_boot_partition
          vol = Volume.new("/boot/efi", ::Storage::VFAT)
          vol.can_live_on_logical_volume = false
          # TO DO
          vol
        end

        def make_prep_partition
          vol = Volume.new("PReP", ::Storage::VFAT)
          vol.can_live_on_logical_volume = false
          # TO DO
          vol
        end
      end

      #
      #----------------------------------------------------------------------
      #

      attr_accessor :settings

      # devicegraph names
      PROPOSAL = "proposal"
      PROBED   = "probed"

      def initialize
        @settings = Settings.new
        @proposal = nil # ::Storage::DeviceGraph
        @disk_blacklist = []
        @disk_greylist  = []
      end

      # Create a storage proposal.
      def propose
        storage = StorageManager.instance # this will start probing in the first invocation
        storage.remove_devicegraph(PROPOSAL) if storage.exist_devicegraph(PROPOSAL)
        @proposal = storage.copy_devicegraph(PROBED, PROPOSAL)

        boot_requirements_checker = BootRequirementsChecker.new(@settings)
        @volumes = boot_requirements_checker.needed_partitions
        @volumes += standard_volumes
        pp @volumes

        space_maker = SpaceMaker.new(@volumes, @settings)
      end

      def proposal_text
        # TO DO
        "No disks found - no storage proposal possible"
      end

      private

      # Return an array of the standard volumes for the root and /home file systems
      #
      # @return [Array [Volume]]
      #
      def standard_volumes
        volumes = [make_root_vol]
        volumes << make_home_vol if @settings.use_separate_home
        volumes
      end

      # Create the Volume data structure for the root volume according to the
      # settings.
      #
      # This does NOT create the partition yet, only the data structure.
      #
      def make_root_vol
        root_vol = Volume.new("/", @settings.root_filesystem_type)
        root_vol.min_size = @settings.root_base_size
        root_vol.max_size = @settings.root_max_size
        if root_vol.filesystem_type = ::Storage::BTRFS
          multiplicator = 1.0 + @settings.btrfs_increase_percentage / 100.0
          root_vol.min_size *= multiplicator
          root_vol.max_size *= multiplicator
        end
        root_vol.desired_size = root_vol.max_size
        root_vol
      end

      # Create the Volume data structure for the /home volume according to the
      # settings.
      #
      # This does NOT create the partition yet, only the data structure.
      #
      def make_home_vol
        home_vol = Volume.new("/home", @settings.home_filesystem_type)
        home_vol.min_size = @settings.home_min_size
        home_vol.max_size = @settings.home_max_size
        home_vol.desired_size = home_vol.max_size
        home_vol
      end
    end
  end
end

# if used standalone, do a minimalistic test case

if $PROGRAM_NAME == __FILE__  # Called direcly as standalone command? (not via rspec or require)
  proposal = Yast::Storage::Proposal.new
  proposal.settings.root_filesystem_type = ::Storage::XFS
  proposal.settings.use_separate_home = true
  proposal.propose
  # pp proposal
end
