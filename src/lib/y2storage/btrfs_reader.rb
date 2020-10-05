# Copyright (c) [2020] SUSE LLC
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

require "y2storage"
require "yast2/execute"

module Y2Storage
  # Class to read Btrfs quota groups
  #
  # In order to read most of the Btrfs meta information, i.e. quota groups, the
  # filesystem must be mounted. This class takes care of mounting the system in
  # read-only, extracting the information and umounting the filesystem again.
  #
  # TODO: This class shares many bits with FilesystemReader.
  #
  # @see FilesystemReader
  class BtrfsReader
    include Yast::Logger

    # Constructor
    #
    # @param filesystem [Filesystems::Btrfs] Filesystem to read information from
    def initialize(filesystem)
      @filesystem = filesystem
      @already_read = false
    end

    # Determines whether quotas are enabled or not
    #
    # TODO: As qgroups are automatically detected, we could consider the quotas to be active
    # as soon as a qgroup exists.
    #
    # @return [Boolean] true if quotas are enabled; false otherwise
    def quotas?
      !!fs_attribute(:quotas)
    end

    # Returns the quota groups list
    #
    # @example Get quotas for a give Btrfs filesystem
    #   btrfs = devicegraph.filesystems.find { |f| f.is?(:btrfs) }
    #   reader = BtrfsQuotasReader.new(btrfs)
    #   reader.qgroups #=> Array<BtrfsQgroup>
    #
    # @return [Array<BtrfsQgroup>] List of qgroups
    def qgroups
      fs_attribute(:qgroups)
    end

    FS_ATTRIBUTES = {
      qgroups: nil,
      quotas:  nil
    }.freeze

    # Attributes that are read from the filesystem
    def fs_attributes
      @fs_attributes ||= FS_ATTRIBUTES.dup
    end

    private

    attr_reader :filesystem

    # Returns the value for a filesystem attribute
    #
    # @param attr [Symbol] :qgroups, :quotas
    # @return [Object]
    def fs_attribute(attr)
      read unless @already_read

      fs_attributes[attr]
    end

    # Save the value of a filesyste attribute
    #
    # @param attr [Symbol]
    # @param value [Object]
    def save_fs_attribute(attr, value)
      fs_attributes[attr] = value
    end

    def read
      Dir.mktmpdir do |mount_point|
        mount(mount_point)
        read_qgroups(mount_point)
        umount(mount_point)
      end
    end

    def read_qgroups(mount_point)
      out, err, code = Yast::Execute.locally!(
        "/usr/sbin/btrfs", "qgroup", "show", "-er", "--sync", mount_point,
        stderr: :capture, stdout: :capture, allowed_exitstatus: 0..1
      )

      enabled = code.zero? || !err.start_with?("ERROR:")
      save_fs_attribute(:quotas, enabled)

      qgroup_lines = out.lines.select { |l| l.start_with?("0/") }
      qgroups = qgroup_lines.map do |line|
        qgroup_id, _rfer, _excl, refr_quota, excl_quota = line.split
        subvol_id = qgroup_id.split("/").last
        BtrfsQgroup.new(subvol_id, quota_size(refr_quota), quota_size(excl_quota))
      end

      save_fs_attribute(:qgroups, qgroups)
    end

    def quota_size(str)
      return nil if str == "none"

      DiskSize.from_human_string(str)
    end

    def mount(mount_point)
      mount_name = "UUID=#{filesystem.uuid}"
      cmd = ["/usr/bin/mount", "-o", "ro", mount_name, mount_point]
      Yast::Execute.locally!(cmd)
    rescue Cheetah::ExecutionFailed
      raise "mount failed for #{mount_name}"
    end

    def umount(mount_point)
      cmd = ["/usr/bin/umount", "-R", mount_point]
      Yast::Execute.locally!(cmd)
    rescue Cheetah::ExecutionFailed
      raise "umount failed for #{mount_point}"
    end
  end
end
