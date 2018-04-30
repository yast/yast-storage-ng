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
require "y2partitioner/device_graphs"

module Y2Partitioner
  module Actions
    module Controllers
      # This class stores information about the fstab files read from all
      # the filesystem in the system. It also saves information about the
      # selected fstab to be used to import mount points.
      class Fstabs
        include Yast::I18n

        # @return [Y2Storage::Fstab] fstab file selected to import mount points
        attr_accessor :selected_fstab

        # Constructor
        def initialize
          textdomain "storage"
        end

        # All fstab files found in the system
        #
        # @return [Array<Y2Storage::Fstab>]
        def fstabs
          disk_analyzer.fstabs
        end

        # Selects the previous fstab
        #
        # The current selected fstab does not change if it already is the first one.
        #
        # @return [Y2Storage::Fstab]
        def select_prev_fstab
          current_index = fstabs.index(selected_fstab)
          prev_index = [0, current_index - 1].max

          @selected_fstab = fstabs.at(prev_index)
        end

        # Selects the next fstab
        #
        # The current selected fstab does not change if it already is the last one.
        #
        # @return [Y2Storage::Fstab]
        def select_next_fstab
          current_index = fstabs.index(selected_fstab)
          next_index = [fstabs.size - 1, current_index + 1].min

          @selected_fstab = fstabs.at(next_index)
        end

        # Checks whether the selected fstab is the first one
        #
        # @return [Boolean]
        def selected_first_fstab?
          selected_fstab == fstabs.first
        end

        # Checks whether the selected fstab is the last one
        #
        # @return [Boolean]
        def selected_last_fstab?
          selected_fstab == fstabs.last
        end

        # Errors in the selected fstab
        #
        # @see #missing_devices_error
        #
        # @return [Array<String>]
        def selected_fstab_errors
          [missing_devices_error].compact
        end

        # Imports mount points from the selected fstab
        #
        # Before importing, the current devicegraph is reset to the system one.
        def import_mount_points
          reset_current_graph
          selected_fstab.filesystem_entries.each { |e| import_mount_point(e) }
        end

      private

        # System devicegraph
        #
        # @return [Y2Storage::Devicegraph]
        def system_graph
          DeviceGraphs.instance.system
        end

        # Current devicegraph
        #
        # @return [Y2Storage::Devicegraph]
        def current_graph
          DeviceGraphs.instance.current
        end

        # Disk analyzer for the system devicegraph
        #
        # @return [Y2Storage::DiskAnalyzer]
        def disk_analyzer
          DeviceGraphs.instance.disk_analyzer
        end

        # Error when some devices in the selected fstab are missing in the current devicegraph
        #
        # @return [String, nil] nil if all devices are found
        def missing_devices_error
          return nil unless missing_devices?

          _("Some required devices cannot be found in the system.")
        end

        # Whether any device in the selected fstab is missing in the system devicegraph
        #
        # @return [Boolean]
        def missing_devices?
          selected_fstab.filesystem_entries.any? { |e| e.device(system_graph).nil? }
        end

        # Initializes current devicegraph with system
        def reset_current_graph
          DeviceGraphs.instance.current = system_graph.dup
        end

        # Imports the mount point of a fstab entry
        #
        # The device in the fstab entry (first field) is formatted using the fileystem type
        # indicated in the entry. In case the device is not a block device (e.g., NFS), the
        # device is not formatted and only the mount point and mount options are assigned.
        #
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        def import_mount_point(entry)
          device = entry.device(current_graph)
          return unless device

          filesystem =
            if device.is?(:blk_device)
              format_device(device, entry.fs_type)
            else
              device
            end

          filesystem.mount_path = entry.mount_point
          filesystem.mount_point.mount_options = entry.mount_options if entry.mount_options.any?
        end

        # Formats the device indicated in the fstab entry
        #
        # @param device [Y2Storage::BlkDevice]
        # @param fs_type [Y2Storage::Filesystems::Type]
        #
        # @return [Y2Storage::Filesystems::Base]
        def format_device(device, fs_type)
          device.delete_filesystem
          device.create_filesystem(fs_type)
        end
      end
    end
  end
end
