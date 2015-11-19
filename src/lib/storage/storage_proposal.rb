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
          @root_filesystem_type     = :Btrfs
          @use_snapshots            = true
          @use_separate_home        = true
          @home_filesystem_type     = :XFS
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
        attr_accessor :btrfs_root_size_multiplicator
        attr_accessor :limit_try_home
        attr_accessor :lvm_keep_unpartitioned_region
        attr_accessor :lvm_desired_size
        attr_accessor :lvm_home_max_size

        def initialize
          super()
          @root_base_size                = DiskSize.GiB(10)
          @root_max_size                 = DiskSize.GiB(40)
          @root_space_percent            = 50
          @btrfs_root_size_multiplicator = 3.0
          @limit_try_home                = DiskSize.GiB(20)
          @lvm_keep_unpartitioned_region = false
          @lvm_desired_size              = DiskSize.GiB(60)
          @lvm_home_max_size             = DiskSize.GiB(100)
        end

        def read_from_xml_file(xml_file_name)
          # TO DO
        end
      end

      # Class to represent a planned volume (partition or logical volume) and
      # its constraints
      #
      class Volume
        attr_accessor :mount_point
        attr_accessor :size, :min_size, :max_size, :desired_size
        attr_accessor :can_live_on_logical_volume, :logical_volume_name

        def initialize(mount_point)
          @mount_point  = mount_point
          @size         = 0
          @min_size     = 0
          @max_size     = -1 # -1: unlimited
          @desired_size = -1 # -1: unlimited (as large as possible)
          @can_live_on_logical_volume = false
          @logical_volume_name = nil

          if @mount_point != "/boot"
            if @mount_point.start_with?("/")
              @can_live_on_logical_volume = true
              if @mount_point == "/"
                @logical_volume_name = "root"
              else
                @logical_volume_name = @mount_point.sub(%r{^/}, "")
              end
            end
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

      #
      #----------------------------------------------------------------------
      #

      attr_accessor :settings

      def initialize
        @settings = Settings.new
        @proposal = ""

        @root_vol = Volume.new("/")
        @home_vol = Volume.new("/home")
        @boot_vol = Volume.new("/boot")
        @prep_vol = Volume.new("PReP")
        @efi_boot_vol = Volume.new("EFI")
        # @bios_grub_vol = Volume.new("BIOS_Grub")

        @volumes = [ @root_vol, @home_vol, @boot_vol ]
      end

      # Check if the current setup requires a /boot partition
      def boot_partition_needed?
        # TO DO
        false
      end

      def add_boot_partition
        # TO DO
      end

      def efi_boot_partition_needed?
        # TO DO
        false
      end

      def add_efi_boot_partition
        # TO DO
      end

      def prep_partition_needed?
        # TO DO
        false
      end

      def add_prep_partition
        # TO DO
      end

      # Figure out which disk to use
      def choose_disk
      end

      # Create a storage proposal.
      def propose
        # TO DO: Reset staging
        StorageManager.start_probing
        space_maker = SpaceMaker.new(@volumes, @settings)
      end

      def proposal_text
        # TO DO
        "No disks found - no storage proposal possible"
      end
    end
  end
end

# if used standalone, do a minimalistic test case

if $PROGRAM_NAME == __FILE__  # Called direcly as standalone command? (not via rspec or require)
  proposal = Yast::Storage::Proposal.new
  proposal.settings.root_filesystem_type = :XFS
  proposal.settings.use_separate_home = false
  proposal.propose
  # pp proposal
end
