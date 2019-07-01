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
    include Yast::I18n

    # @return [Devicegraph]
    attr_reader :devicegraph

    # Constructor
    #
    # @param devicegraph [Devicegraph] devicegraph to sanitize
    def initialize(devicegraph)
      textdomain "storage"

      @devicegraph = devicegraph
    end

    # Errors that need to be fixed in order to obtain a sanitized devicegraph
    #
    # @return [Array<DevicegraphSanitizer::Error>] empty if the devicegraph is
    #   already sanitized.
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

    # Sanitizes a given devicegraph
    #
    # @note The given devicegraph is modified.
    #
    # @param devicegraph [Y2Storage::Devicegraph]
    # @return [Y2Storage::Devicegraph]
    def sanitize(devicegraph)
      errors_for(devicegraph).each { |e| fix_error(devicegraph, e) }
      devicegraph
    end

    # Fixes an specific error in the given devicegraph
    #
    # @note The given devicegraph is modified.
    #
    # @param devicegraph [Y2Storage::Devicegraph]
    # @param error [Y2Storage::DevicegraphSanitizer::Error] error to fix
    # @return [Y2Storage::Devicegraph]
    def fix_error(devicegraph, error)
      device = error.device

      fix_error_for_lvm_vg(devicegraph, device) if device.is?(:lvm_vg)
      fix_error_for_bcache(devicegraph, device) if device.is?(:bcache) || device.is?(:bcache_cset)
      devicegraph
    end

    # Fixes an error with an LVM VG in a given devicegraph
    #
    # @note The given devicegraph is modified.
    #
    # @param devicegraph [Y2Storage::Devicegraph]
    # @param vg [Y2Storage::LvmVg] vg with the error
    # @return [Y2Storage::Devicegraph]
    def fix_error_for_lvm_vg(devicegraph, vg)
      devicegraph.remove_lvm_vg(vg)
      devicegraph
    end

    # Errors in the given devicegraph
    #
    # @param devicegraph [Y2Storage::Devicegraph]
    # @return [Array<DevicegraphSanitizer::Error>]
    def errors_for(devicegraph)
      errors = errors_for_lvm_vgs(devicegraph)
      errors.concat(errors_for_bcache(devicegraph))
    end

    # Errors related to LVM VGs in the given devicegraph
    #
    # @param devicegraph [Y2Storage::Devicegraph]
    # @return [Array<DevicegraphSanitizer::Error>]
    def errors_for_lvm_vgs(devicegraph)
      devicegraph.lvm_vgs.map { |v| error_for_lvm_vg(v) }.compact
    end

    # Error with an LVM VGs
    #
    # @param vg [Y2Storage::LvmVg] vg to check
    # @return [DevicegraphSanitizer::Error, nil] nil if the LVM VG is correct
    def error_for_lvm_vg(vg)
      return nil unless missing_pvs?(vg)

      Error.new(vg, error_message_for_lvm_vg(vg))
    end

    # Error message for an incomplete LVM VG (missing PVs)
    #
    # @param vg [Y2Storage::LvmVg]
    # @return [String]
    def error_message_for_lvm_vg(vg)
      if Yast::Mode.installation
        # TRANSLATORS: %{name} is the name of an LVM Volume Group (e.g., /dev/vg1)
        format(
          _("The volume group %{name} is incomplete because some physical volumes are missing.\n" \
            "If you continue, the volume group will be deleted later as part of the installation\n" \
            "process. Moreover, incomplete volume groups are ignored by the partitioning proposal\n" \
            "and are not visible in the Expert Partitioner."),
          name: vg.name
        )
      else
        # TRANSLATORS: %{name} is the name of an LVM Volume Group (e.g., /dev/vg1)
        format(
          _("The volume group %{name} is incomplete because some physical volumes are missing.\n" \
            "Incomplete volume groups are not visible in the Partitioner and will be deleted at the\n" \
            "final step, when all the changes are performed in the system."),
          name: vg.name
        )
      end
    end

    # Checks whether an LVM VG has missing PVs
    #
    # @param vg [Y2Storage::LvmVg]
    # @return [Boolean]
    def missing_pvs?(vg)
      vg.lvm_pvs.any? { |p| p.blk_device.nil? }
    end

    # Errors related to bcache in the given devicegraph
    #
    # @param devicegraph [Y2Storage::Devicegraph]
    # @return [Array<DevicegraphSanitizer::Error>]
    def errors_for_bcache(devicegraph)
      return [] if Bcache.supported?

      bcache_dev = first_bcache_device(devicegraph)
      return [] if bcache_dev.nil?

      [Error.new(bcache_dev, msg_no_bcache_support)]
    end

    # Find the first bcache of BcacheCset device in the devicegraph
    # or nil if there is none.
    #
    # @return [Y2Storage::Device, nil]
    def first_bcache_device(devicegraph)
      Bcache.all(devicegraph).first || BcacheCset.all(devicegraph).first
    end

    # Error message for missing bcache support on this platform
    #
    # @return [String]
    def msg_no_bcache_support
      msg = _("Bcache detected, but bcache is not supported on this platform!")
      msg += "\n\n"
      msg + _("This may or may not work. Use at your own risk.\n" \
               "The safe way is to remove this bcache manually\n" \
               "with command line tools and then restart YaST.")
    end

    # Fix an error for a Bcache or BcacheCset in a devicegraph.
    #
    # @param devicegraph [Y2Storage::Devicegraph]
    # @param _device [Y2Storage::Device] not used
    # @return [Y2Storage::Devicegraph]
    def fix_error_for_bcache(devicegraph, _device)
      devicegraph
    end

    # Class to represent an error in a devicegraph
    class Error
      # @return [Y2Storage::Device]
      attr_reader :device

      # @return [String]
      attr_reader :message

      # Constructor
      #
      # @param device [Y2Storage::Device]
      # @param message [String]
      def initialize(device, message)
        @device = device
        @message = message
      end
    end
  end
end
