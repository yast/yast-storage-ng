# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

require "y2storage/storage_class_wrapper"

module Y2Storage
  # Information about one line in fstab
  #
  # This is a wrapper for Storage::SimpleEtcFstabEntry
  class SimpleEtcFstabEntry
    include StorageClassWrapper
    wrap_class Storage::SimpleEtcFstabEntry

    # @!method fstab_device
    #   @return [String] device in the fstab file
    storage_forward :fstab_device, to: :device

    # @!method mount_point
    #   @return [String]
    storage_forward :mount_point

    # @!method fs_type
    #   @return [Filesystems::Type]
    storage_forward :fs_type, as: "Filesystems::Type"

    # @!method mount_options
    #   @return [Array<String>]
    storage_forward :mount_options

    # @!method fs_freq
    #   @return [Integer]
    storage_forward :fs_freq

    # @!method fs_passno
    #   @return [Integer]
    storage_forward :fs_passno

    # Checks whether the entry is for a BTRFS subvolume
    #
    # @return [Boolean]
    def subvolume?
      mount_options.any? { |o| o.match?("subvol=") }
    end

    # Filesystem for the fstab entry
    #
    # @param devicegraph [Devicegraph]
    # @return [Filesystems::Base, nil]
    def filesystem(devicegraph)
      devicegraph.filesystems.find { |f| f.match_fstab_spec?(fstab_device) }
    end

    # Device for the fstab entry
    #
    # @note When the filesystem is NFS, the filesystem is considered as the entry device.
    #
    # @note When the entry refers to an encryption device, it returs the encryption device
    # and not the underlying device.
    #
    # @param devicegraph [Devicegraph]
    # @return [BlkDevice, Filesystems::Nfs, nil]
    def device(devicegraph)
      filesystem = filesystem(devicegraph)

      if !filesystem
        find_device(devicegraph)
      elsif filesystem.respond_to?(:blk_devices)
        filesystem.blk_devices.first
      else
        filesystem
      end
    end

  private

    # Tries to find the device for the fstab entry
    #
    # @param devicegraph [Devicegraph]
    # @return [BlkDevice, nil]
    def find_device(devicegraph)
      return nil if start_with_uuid? || start_with_label?

      devicegraph.find_by_any_name(fstab_device)
    end

    def start_with_uuid?
      /^UUID=(.*)/.match?(fstab_device)
    end

    def start_with_label?
      /^LABEL=(.*)/.match?(fstab_device)
    end
  end
end
