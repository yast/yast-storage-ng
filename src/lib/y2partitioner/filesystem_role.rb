# Copyright (c) [2017-2018] SUSE LLC
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
require "y2storage"

Yast.import "Mode"

module Y2Partitioner
  # Class to represent each one of the roles presented to the user when creating
  # a new partition, LVM logical volume or MD RAID.
  class FilesystemRole
    include Yast::I18n
    extend Yast::I18n

    # Constructor, to be used internally by the class
    #
    # @param id [Symbol] id of the role
    # @param name [String] string marked for translation, see {#name}
    # @param part_id [Symbol] used to initialize {#partition_id}
    # @param fs_type [Symbol, nil] used to initialize {#filesystem_type}
    def initialize(id, name, part_id, fs_type)
      textdomain "storage"

      @id = id
      @name = name
      @partition_id = Y2Storage::PartitionId.find(part_id)
      @filesystem_type = Y2Storage::Filesystems::Type.find(fs_type) if fs_type
    end

    # All possible instances
    ALL = [
      new(:system,   N_("Operating System"),          :linux, :btrfs),
      new(:data,     N_("Data and ISV Applications"), :linux, :xfs),
      new(:swap,     N_("Swap"),                      :swap,  :swap),
      new(:efi_boot, N_("EFI Boot Partition"),        :esp,   :vfat),
      new(:raw,      N_("Raw Volume (unformatted)"),  :lvm,   nil)
    ].freeze
    private_constant :ALL

    # Sorted list of all possible roles
    def self.all
      ALL.dup
    end

    # Finds a role by its id
    #
    # @param id [Symbol, nil]
    # @return [FilesystemRole, nil] nil if such role id does not exist
    def self.find(id)
      ALL.find { |role| role.id == id }
    end

    # @return [Symbol] value used as identifier and as index to find the role
    attr_reader :id

    # @return [Y2Storage::PartitionId] default id for a partition with the role
    attr_reader :partition_id

    # @return [Y2Storage::Filesystems::Type, nil] type of the filesystem to
    #   create for the role, nil if no filesystem is needed
    attr_reader :filesystem_type

    # @return [String] localized name of the role to display in the UI
    def name
      _(@name)
    end

    # Default mount path for the role
    #
    # Some roles will pick one of the paths offered by the UI (see arguments)
    # but others will ignore the list and return a hardcoded mandatory path.
    #
    # @param paths [Array<String>] list of paths that are offered by the UI
    # @return [String, nil] nil if the device must not be mounted by default
    def mount_path(paths)
      case id
      when :swap
        "swap"
      when :efi_boot
        "/boot/efi"
      when :raw
        nil
      else
        # Behavior of the old SingleMountPointProposal (behavior introduced
        # back in 2005 with unknown rationale)
        paths.first unless Yast::Mode.normal
      end
    end

    # Whether the checkbox about configuring snapper should be activated by
    # default for this role in a given device
    #
    # This returns the value of the checkbox in case it is present, deciding
    # whether to show the checkbox at all or not is out of the scope of this
    # method.
    #
    # @param device [Y2Storage::BlkDevice] device being created and formatted
    # @return [Boolean]
    def snapper?(device)
      return false if id != :system || device.filesystem.nil?

      device.filesystem.default_configure_snapper?
    end
  end
end
