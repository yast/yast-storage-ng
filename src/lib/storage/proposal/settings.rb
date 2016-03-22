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

require "storage/disk_size"

module Yast
  module Storage
    class Proposal
      #
      # User-configurable settings for the storage proposal.
      # Those are settings the user can change in the UI.
      #
      class UserSettings
        include Yast::Logger

        attr_accessor :use_lvm, :encrypt_volume_group
        attr_accessor :root_filesystem_type, :use_snapshots
        attr_accessor :use_separate_home, :home_filesystem_type
        attr_accessor :enlarge_swap_for_suspend

        def initialize
          @use_lvm                  = false
          @encrypt_volume_group     = false
          @root_filesystem_type     = ::Storage::FsType_BTRFS
          @use_snapshots            = true
          @use_separate_home        = true
          @home_filesystem_type     = ::Storage::FsType_XFS
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
        # Free disk space below this size will be disregarded
        attr_accessor :useful_free_space_min_size

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
          @useful_free_space_min_size    = DiskSize.MiB(30)
        end
      end
    end
  end
end
