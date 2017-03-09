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
require "y2storage/disk_size"
require "y2storage/secret_attributes"

module Y2Storage
  #
  # User-configurable settings for the storage proposal.
  # Those are settings the user can change in the UI.
  #
  class ProposalUserSettings
    include Yast::Logger
    include SecretAttributes

    attr_accessor :use_lvm
    attr_accessor :root_filesystem_type, :use_snapshots
    attr_accessor :use_separate_home, :home_filesystem_type
    attr_accessor :enlarge_swap_for_suspend
    attr_accessor :root_device, :candidate_devices
    secret_attr   :encryption_password

    def initialize
      @use_lvm                  = false
      self.encryption_password  = nil
      @root_filesystem_type     = ::Storage::FsType_BTRFS
      @use_snapshots            = true
      @use_separate_home        = true
      @home_filesystem_type     = ::Storage::FsType_XFS
      @enlarge_swap_for_suspend = false
    end

    def use_encryption
      !encryption_password.nil?
    end
  end

  # Per-product settings for the storage proposal.
  # Those settings are read from /control.xml on the installation media.
  # The user can directly override the part inherited from UserSettings.
  #
  class ProposalSettings < ProposalUserSettings
    attr_accessor :root_base_disk_size
    attr_accessor :root_max_disk_size
    attr_accessor :root_space_percent
    attr_accessor :btrfs_increase_percentage
    attr_accessor :min_size_to_use_separate_home
    attr_accessor :btrfs_default_subvolume
    attr_accessor :root_subvolume_read_only
    attr_accessor :home_min_disk_size
    attr_accessor :home_max_disk_size

    def initialize
      super
      # Default values taken from SLE-12-SP1
      @root_base_disk_size           = DiskSize.GiB(3)
      @root_max_disk_size            = DiskSize.GiB(10)
      @root_space_percent            = 40
      @min_size_to_use_separate_home = DiskSize.GiB(5)
      @btrfs_increase_percentage     = 300.0
      @btrfs_default_subvolume       = "@"
      @root_subvolume_read_only      = false

      # Not yet in control.xml
      @home_min_disk_size            = DiskSize.GiB(10)
      @home_max_disk_size            = DiskSize.unlimited
    end
  end
end
