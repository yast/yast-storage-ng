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
require "y2storage/devicegraph"
require "y2storage/bcache"
require "y2storage/bcache_cset"

require "abstract_method"

Yast.import "Mode"

module Y2Storage
  # Class to sanitize a devicegraph
  #
  # A devicegraph can contain certain errors, for example, an LVM VG with missing PVs.
  # This class fixes wrong devices (typically by removing them).
  #
  # @example
  #   sanitizer = DevicegraphSanitizer.new(devicegraph)
  #   new_devicegraph = sanitizer.sanitized_devicegraph
  class DevicegraphSanitizer
    # @return [Devicegraph]
    attr_reader :devicegraph

    # Constructor
    #
    # @param devicegraph [Devicegraph] devicegraph to sanitize
    def initialize(devicegraph)
      @devicegraph = devicegraph
    end

    # Errors that need to be fixed in order to obtain a sanitized devicegraph
    #
    # @return [Array<DevicegraphSanitizer::Error>] empty if the devicegraph is already sanitized.
    def errors
      @errors ||= errors_for(devicegraph)
    end

    # Sanitized version of the devicegraph
    #
    # @return [Y2Storage::Devicegraph]
    def sanitized_devicegraph
      @sanitized_devicegraph ||= sanitize(devicegraph.dup)
    end

    private

    # Errors in the given devicegraph
    #
    # @param devicegraph [Y2Storage::Devicegraph]
    # @return [Array<DevicegraphSanitizer::Error>]
    def errors_for(devicegraph)
      lvm_vgs_errors(devicegraph) +
        bcaches_errors(devicegraph) +
        filesystems_errors(devicegraph)
    end

    # Errors related to LVM VGs in the given devicegraph
    #
    # @param devicegraph [Y2Storage::Devicegraph]
    # @return [Array<DevicegraphSanitizer::Error>]
    def lvm_vgs_errors(devicegraph)
      devicegraph.lvm_vgs.flat_map { |v| lvm_vg_errors(v) }.compact
    end

    # Errors for an LVM VG
    #
    # @param vg [Y2Storage::LvmVg]
    # @return [Array<DevicegraphSanitizer::Error>]
    def lvm_vg_errors(vg)
      errors = []

      errors << MissingLvmPvError.new(vg) if MissingLvmPvError.check(vg)

      errors
    end

    # Errors related to Bcache in the given devicegraph
    #
    # @param devicegraph [Y2Storage::Devicegraph]
    # @return [Array<DevicegraphSanitizer::Error>]
    def bcaches_errors(devicegraph)
      errors = []

      errors << UnsupportedBcacheError.new if UnsupportedBcacheError.check(devicegraph)

      errors
    end

    # Errors related to filesystems in the given devicegraph
    #
    # @param devicegraph [Y2Storage::Devicegraph]
    # @return [Array<DevicegraphSanitizer::Error>]
    def filesystems_errors(devicegraph)
      devicegraph.filesystems.flat_map { |f| filesystem_errors(f) }.compact
    end

    # Errors for a filesystem
    #
    # @param filesystem [Y2Storage::Filesystems::Base]
    # @return [Array<DevicegraphSanitizer::Error>]
    def filesystem_errors(filesystem)
      errors = []

      errors << InactiveRootError.new(filesystem) if InactiveRootError.check(filesystem)

      errors
    end

    # Sanitizes a given devicegraph
    #
    # @note The given devicegraph is modified.
    #
    # @param devicegraph [Y2Storage::Devicegraph]
    # @return [Y2Storage::Devicegraph]
    def sanitize(devicegraph)
      errors_for(devicegraph).each { |e| e.fix(devicegraph) }

      devicegraph
    end

    # Class to represent an error in a devicegraph
    class Error
      include Yast::I18n

      # @return [Y2Storage::Device]
      attr_reader :device

      # Constructor
      #
      # @param device [Y2Storage::Device]
      def initialize(device)
        textdomain "storage"

        @device = device
      end

      # @!method message
      #   Error message
      #
      #   @return [String]
      abstract_method :message

      # @!method fix(devicegraph)
      #   Fixes the error in the given devicegraph
      #
      #   @param devicegraph [Y2Storage::Devicegraph]
      #   @return [Y2Storage::Devicegraph]
      abstract_method :fix
    end

    # Error when a LVM VG has missing PVs
    class MissingLvmPvError < Error
      # Checks whether the given LVM VG has missing PVs
      #
      # @param vg [Y2Storage::LvmVg]
      # @return [Boolean]
      def self.check(vg)
        vg.lvm_pvs.any? { |p| p.blk_device.nil? }
      end

      # @see Error#initialize
      def initialize(device)
        super

        @fixed = false
      end

      # Error message for an incomplete LVM VG (missing PVs)
      #
      # @return [String]
      def message
        if Yast::Mode.installation
          # TRANSLATORS: %{name} is the name of an LVM Volume Group (e.g., /dev/vg1)
          format(
            _("The volume group %{name} is incomplete because some physical volumes are missing.\n" \
              "If you continue, the volume group will be deleted later as part of the installation\n" \
              "process. Moreover, incomplete volume groups are ignored by the partitioning proposal\n" \
              "and are not visible in the Expert Partitioner."),
            name: device.name
          )
        else
          # TRANSLATORS: %{name} is the name of an LVM Volume Group (e.g., /dev/vg1)
          format(
            _("The volume group %{name} is incomplete because some physical volumes are missing.\n" \
            "Incomplete volume groups are not visible in the Partitioner and will be deleted at the\n" \
            "final step, when all the changes are performed in the system."),
            name: device.name
          )
        end
      end

      # Fixes the error by removing the LVM VG
      #
      # @note The given devicegraph is modified.
      #
      # @param devicegraph [Y2Storage::Devicegraph]
      # @return [Y2Storage::Devicegraph]
      def fix(devicegraph)
        return devicegraph if @fixed

        devicegraph.remove_lvm_vg(device)

        @fixed = true

        devicegraph
      end
    end

    # Error when Bcache is not supported and there are Bcache devices
    class UnsupportedBcacheError < Error
      # Checks whether Bcache is not supported and the given devicegraph contains any Bcache device
      #
      # @param devicegraph [Y2Storage::Devicegraph]
      # @return [Boolean]
      def self.check(devicegraph)
        return false if Bcache.supported?

        device = Bcache.all(devicegraph).first || BcacheCset.all(devicegraph).first

        !device.nil?
      end

      def initialize
        super(nil)
      end

      # Error message for missing Bcache support on the current platform
      #
      # @return [String]
      def message
        msg = _("Bcache detected, but bcache is not supported on this platform!")
        msg += "\n\n"
        msg + _("This may or may not work. Use at your own risk.\n" \
                "The safe way is to remove this bcache manually\n" \
                "with command line tools and then restart YaST.")
      end

      # The error cannot be fixed
      #
      # @param devicegraph [Y2Storage::Devicegraph]
      # @return [Y2Storage::Devicegraph]
      def fix(devicegraph)
        devicegraph
      end
    end

    # Error when the root filesystem is not currently mounted
    class InactiveRootError < Error
      # Checks whether the given filesystem is root but its mount point is inactive (not mounted)
      #
      # A root filesystem might be probed with an inactive mount point when a snapshot rollback is
      # performed but the system has not been rebooted yet. In that scenario, /etc/fstab contains an
      # entry for root, but /proc/mounts would contain none entry for the new default subvolume.
      #
      # @param filesystem [Y2Storage::Filesystems::Base]
      # @return [Boolean]
      def self.check(filesystem)
        filesystem.root? && !filesystem.mount_point.active?
      end

      # Error message
      #
      # @return [String]
      def message
        msg = _("The root filesystem looks like not currently mounted!")

        if device.is?(:btrfs)
          msg += _(
            "\n\n" \
            "If you have executed a snapshot rollback, please reboot your system before continuing."
          )
        end

        msg
      end

      # The error cannot be fixed
      #
      # @param devicegraph [Y2Storage::Devicegraph]
      # @return [Y2Storage::Devicegraph]
      def fix(devicegraph)
        devicegraph
      end
    end
  end
end
