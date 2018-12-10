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
require "yast2/execute"
require "y2storage/fstab"

Yast.import "OSRelease"

module Y2Storage
  # Class representing a filesystem in the system and providing
  # convenience methods to inspect its content
  class ExistingFilesystem
    include Yast::Logger

    # @return [Filesystems::Base]
    attr_reader :filesystem

    # Constructor
    #
    # @param filesystem [Filesystems::Base]
    # @param root [String]
    # @param mount_point [String]
    def initialize(filesystem, root = "/", mount_point = "/mnt")
      @filesystem = filesystem
      @root = root
      @mount_point = mount_point
      @rpi_boot = false
      @processed = false
    end

    # Device to which the filesystem belongs to
    #
    # @return [BlkDevice]
    def device
      filesystem.blk_devices.first
    end

    # Reads the release name from the filesystem
    #
    # @return [String, nil] nil if the release name cannot be read
    def release_name
      set_attributes unless processed?
      @release_name
    end

    # Reads the fstab file from the filesystem
    #
    # @return [Fstab, nil] nil if the fstab file cannot be read
    def fstab
      set_attributes unless processed?
      @fstab
    end

    # Read the crypttab file from the filesystem
    #
    # @return [Crypttab, nil] nil if the crypttab file cannot be read
    def crypttab
      set_attributes unless processed?
      @crypttab
    end

    # Whether the filesystem contains the Raspberry Pi boot code in
    # the root path
    #
    # @return [Boolean]
    def rpi_boot?
      set_attributes unless processed?
      @rpi_boot
    end

  protected

    # @return [Boolean] if the filesystem was already mounted to read all the relevant info
    attr_reader :processed
    alias_method :processed?, :processed

    def set_attributes
      mount
      @release_name = read_release_name
      @fstab = read_fstab
      @crypttab = read_crypttab
      @rpi_boot = check_rpi_boot
      umount
    rescue RuntimeError => ex # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
      log.error("CAUGHT exception: #{ex} for #{device.name}")
      nil
    ensure
      @processed = true
    end

    # Mounts the device
    #
    # @see execute
    #
    # @note libstorage-ng has a couple of ways for immediate mounting/unmounting devices, but
    #   they cannot be easily used here.
    #
    #   For example, BlkFilesystem::detect_content_info uses an internal EnsureMounted object.
    #   EnsureMounted mounts a given filesystem during its construction and unmounts it during
    #   its destuction. In ruby there is no a clear way of calling the destructor of a binding
    #   object, so EnsureMounted cannot be used for a temporary mount to inspect the filesystem
    #   content from YaST and then unmount it.
    #
    #   Besides that, MountPoint offers MountPoint::immediate_activate and ::immediate_deactivate,
    #   but these methods only can be used with probed mount points. Internally, these methods
    #   use Mountable::Impl::immediate_activate and ::immediate_deactivate. Such methdos could
    #   be offered in the public API, but they require to create a temporary mount point for the
    #   filesystem to mount. Creating a mount point could have some implications, see
    #   {Device#update_etc_status}, and moreover, a possible existing mount point should be
    #   correctly restored.
    #
    #   The library API needs to be extended to easily mount/umount a device in an arbitrary
    #   path without modifying the device (i.e., without changing its current mount point).
    #
    # @raise [RuntimeError] when the device cannot be mounted
    def mount
      cmd = ["/usr/bin/mount", "-o", "ro", device.name, @mount_point]

      raise "mount failed for #{device.name}" unless execute(*cmd)
    end

    # Unmounts the device
    #
    # @see mount
    #
    # @raise [RuntimeError] when the device cannot be unmounted
    def umount
      cmd = ["/usr/bin/umount", "-R", @mount_point]

      raise "umount failed for #{@mount_point}" unless execute(*cmd)
    end

    # Tries to read the release name
    #
    # @return [String, nil] nil if the filesystem does not contain a release name
    def read_release_name
      release_name = Yast::OSRelease.ReleaseName(@mount_point)
      release_name.empty? ? nil : release_name
    end

    # Tries to read a fstab file
    #
    # @return [Fstab, nil] nil if the filesystem does not contain a fstab file
    def read_fstab
      fstab_path = File.join(@mount_point, "etc", "fstab")
      return nil unless File.exist?(fstab_path)

      Fstab.new(fstab_path, filesystem)
    end

    # Tries to read a crypttab file
    #
    # @return [Crypttab, nil] nil if the filesystem does not contain a crypttab file
    def read_crypttab
      crypttab_path = File.join(@mount_point, "etc", "crypttab")
      return nil unless File.exist?(crypttab_path)

      Crypttab.new(crypttab_path, filesystem)
    end

    # Checks whether the Raspberry Pi boot code is in the root of the
    # filesystem
    #
    # @return [Boolean]
    def check_rpi_boot
      # Only lower-case is expected, but since casing is usually tricky in FAT
      # filesystem, let's do a second check just in case
      ["bootcode.bin", "BOOTCODE.BIN"].each do |name|
        path = File.join(@mount_point, name)
        return true if File.exist?(path)
      end

      false
    end

    # Executes a given command
    #
    # For possible parameters, see Yast::Execute.locally!.
    #
    # @return [Boolean] true if the command finishes correctly; false otherwise.
    def execute(*args)
      Yast::Execute.locally!(*args)
      true
    rescue Cheetah::ExecutionFailed
      false
    end
  end
end
