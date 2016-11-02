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

module Y2Storage
  #
  # Class representing a filesystem in the system and providing
  # convenience methods to inspect its content
  #
  class ExistingFilesystem
    include Yast::Logger

    def initialize(device_name)
      @device_name = device_name
    end

    # Mount the filesystem, perform the check given in 'block' while mounted,
    # and then unmount. The block will get the mount point as a parameter.
    #
    # @return the return value of 'block' or 'nil' if there was an error.
    #
    def mount_and_check(&block)
      raise ArgumentError, "Code block required" unless block_given?
      mount_point = "/mnt" # FIXME
      begin
        # check if we have a filesystem
        # return false unless vol.filesystem
        mount(mount_point)
        check_result = block.call(mount_point)
        umount(mount_point)
        check_result
      rescue RuntimeError => ex # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
        log.error("CAUGHT exception: #{ex} for #{device_name}")
        nil
      end
    end

  protected

    attr_reader :device_name

    # Mount the device.
    #
    # This is a temporary workaround until the new libstorage can handle that.
    #
    def mount(mount_point)
      # FIXME: use libstorage function when available
      cmd = "/usr/bin/mount #{device_name} #{mount_point} >/dev/null 2>&1"
      log.debug("Trying to mount #{device_name}: #{cmd}")
      raise "mount failed for #{device_name}" unless system(cmd)
    end

    # Unmount a device.
    #
    # This is a temporary workaround until the new libstorage can handle that.
    #
    def umount(mount_point)
      # FIXME: use libstorage function when available
      cmd = "/usr/bin/umount #{mount_point}"
      log.debug("Unmounting: #{cmd}")
      raise "umount failed for #{mount_point}" unless system(cmd)
    end
  end
end
