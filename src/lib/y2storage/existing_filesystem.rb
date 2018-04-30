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
require "y2storage/fstab"

Yast.import "OSRelease"

module Y2Storage
  #
  # Class representing a filesystem in the system and providing
  # convenience methods to inspect its content
  #
  class ExistingFilesystem
    include Yast::Logger

    attr_reader :filesystem

    def initialize(filesystem, root = "/", mount_point = "/mnt")
      @filesystem = filesystem
      @root = root
      @mount_point = mount_point
      @processed = false
    end

    def device
      filesystem.blk_devices.first
    end

    def installation_medium?
      set_attributes unless processed?
      @installation_medium
    end

    def release_name
      set_attributes unless processed?
      @release_name
    end

    def fstab
      set_attributes unless processed?
      @fstab
    end

  protected

    attr_reader :processed
    alias_method :processed?, :processed

    def set_attributes
      mount
      @installation_medium = check_installation_medium
      @release_name = read_release_name
      @fstab = read_fstab
      umount
    rescue RuntimeError => ex # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
      log.error("CAUGHT exception: #{ex} for #{device.name}")
      nil
    ensure
      @processed = true
    end

    # Mount the device.
    #
    # This is a temporary workaround until the new libstorage can handle that.
    #
    def mount
      # FIXME: use libstorage function when available
      cmd = "/usr/bin/mount -o ro #{device.name} #{@mount_point} >/dev/null 2>&1"
      log.debug("Trying to mount #{device.name}: #{cmd}")
      raise "mount failed for #{device.name}" unless system(cmd)
    end

    # Unmount a device.
    #
    # This is a temporary workaround until the new libstorage can handle that.
    #
    def umount
      # FIXME: use libstorage function when available
      cmd = "/usr/bin/umount -R #{@mount_point}"
      log.debug("Unmounting: #{cmd}")
      raise "umount failed for #{@mount_point}" unless system(cmd)
    end

    # Check if the filesystem mounted at 'mount_point' is an installation medium.
    #
    # @return [Boolean] 'true' if it is an installation medium, 'false' if not.
    def check_installation_medium
      control_file = "control.xml"
      instsys_control_file = File.join(@root, control_file)
      current_control_file = File.join(@mount_point, control_file)

      return false unless File.exist?(current_control_file)

      if !File.exist?(instsys_control_file)
        log.error("ERROR: Check file #{instsys_control_file} does not exist in inst-sys")
        return false
      end

      FileUtils.identical?(instsys_control_file, current_control_file)
    end

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
  end
end
