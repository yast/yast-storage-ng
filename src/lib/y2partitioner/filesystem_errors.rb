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

require "yast"
require "yast/i18n"
require "y2storage"

Yast.import "Mode"

module Y2Partitioner
  # Mixin to obtain errors from a filesystem. Useful for some widgets,
  # see for example {Y2Partitioner::Widgets::MdDevicesSelector}.
  module FilesystemErrors
    include Yast::I18n

    # Errors for the given filesystem
    #
    # @note When new_size is indicated, that value is considered instead of the
    #   actual size of the filesystem.
    #
    # @see #small_size_for_snapshots_error
    #
    # @param filesystem [Y2Storage::Filesystems::Base, nil]
    # @param new_size [Y2Storage::DiskSize, nil]
    #
    # @return [Array<String>]
    def filesystem_errors(filesystem, new_size: nil)
      [small_size_for_snapshots_error(filesystem, new_size: new_size)].compact
    end

  private

    # Error when the size of the filesystem is too small for snapshots
    #
    # This check is only performed during installation.
    #
    # @see #small_size_for_snapshots?
    #
    # @param filesystem [Y2Storage::Filesystems::Base, nil]
    # @param new_size [Y2Storage::DiskSize, nil]
    #
    # @return [String, nil] nil if size is ok or no check is performed.
    def small_size_for_snapshots_error(filesystem, new_size: nil)
      textdomain "storage"

      return nil unless installing? && small_size_for_snapshots?(filesystem, new_size: new_size)

      format(
        _("Your %{name} device is very small for snapshots.\n" \
          "We recommend to increase the size of the %{name} device\n" \
          "to at least %{min_size} or to disable snapshots."),
        name:     filesystem.root? ? _("root") : filesystem.mount_path,
        min_size: min_size_for_snapshots(filesystem).to_human_string
      )
    end

    # Whether running in installation mode
    #
    # @return [Boolean]
    def installing?
      Yast::Mode.installation
    end

    # Whether the filesystem size is too small for snapshots
    #
    # The min size for snapshots is obtained from the volume specification
    # for the device where the filesystem is placed. In case of no volume
    # specification for that device, it returns false.
    #
    # @see #min_size_for_snapshots
    #
    # @param filesystem [Y2Storage::Filesystems::Base, nil]
    # @param new_size [Y2Storage::DiskSize, nil]
    #
    # @return [Boolean]
    def small_size_for_snapshots?(filesystem, new_size: nil)
      return false unless filesystem && filesystem_with_snapshots?(filesystem)

      # TODO: check size for multidevice Btrfs
      return false if filesystem.multidevice?

      size = new_size || filesystem.blk_devices.first.size
      min_size = min_size_for_snapshots(filesystem)

      min_size && size < min_size
    end

    # Whether the filesystem is configured to have snapshots
    #
    # @param filesystem [Y2Storage::Filesystems::Base, nil]
    # @return [Boolean]
    def filesystem_with_snapshots?(filesystem)
      return false unless filesystem && filesystem.respond_to?(:configure_snapper)

      filesystem.configure_snapper
    end

    # Min size to support snapshots
    #
    # The min size for snapshots is obtained from the volume specification
    # for the device where the filesystem is placed. In case of no volume
    # specification for that device, it returns nil.
    #
    # @see Y2Storage::VolumeSpecification#min_size_with_snapshots
    #
    # @param filesystem [Y2Storage::Filesystems::Base, nil]
    # @return [Y2Storage::DiskSize, nil] nil if min size for snapshots cannot
    #   be obtained.
    def min_size_for_snapshots(filesystem)
      return nil unless filesystem && filesystem.mount_point

      spec = Y2Storage::VolumeSpecification.for(filesystem.mount_path)
      return nil unless spec

      spec.min_size_with_snapshots
    end
  end
end
