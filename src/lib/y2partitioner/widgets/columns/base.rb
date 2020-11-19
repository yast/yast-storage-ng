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

require "yast"
require "abstract_method"
require "y2partitioner/device_graphs"
require "y2partitioner/bidi"

module Y2Partitioner
  module Widgets
    module Columns
      # Base class for all widgets representing a column of a table displaying a collection of
      # devices
      #
      # Each subclass must define the following methods:
      #
      #   * #title returning the column title.
      #   * #value_for(device) returning the content to display for the given device.
      #
      # Additionally, if the subclass needs access to the information contained directly in the
      # table entry, it can redefine {#entry_value} which in the base class is just a direct
      # call to {#value_for} with the device of the entry as single argument.
      #
      # @example
      #   class StorageId < Base
      #     def title
      #       _("SID")
      #     end
      #
      #     def value_for(device)
      #       device.respond_to?(:storage_id) ? device.storage_id : "N/A"
      #     end
      #   end
      #
      #   class DeviceName < Base
      #     def title
      #       _("SID")
      #     end
      #
      #     def value_for(device)
      #       device.respond_to?(:name) ? device.name : "N/A"
      #     end
      #   end
      #
      #   class Widgets::SimpleDevicesTable < Widgets::BlkDevicesTable
      #     def devices
      #       @devices ||= Y2Storage::Device.all
      #     end
      #
      #     def columns
      #       [
      #         Columns::StorageId,
      #         Columns::DeviceName
      #       ]
      #     end
      #   end
      class Base
        extend Yast::I18n
        include Yast::I18n
        include Yast::UIShortcuts

        # @!method title
        #   Title of the column
        #
        #   @return [String, Yast::Term]
        abstract_method :title

        # @!method value_for(device)
        #   The value to display for the given device
        #
        #   @param device [Y2Storage::Device, Y2Storage::SimpleEtcFstabEntry]
        #   @return [String, Yast::Term]
        abstract_method :value_for

        # The value to display for the given table entry
        #
        # @param entry [DeviceTableEntry]
        # @return [String, Yast::Term]
        def entry_value(entry)
          value_for(entry.device)
        end

        # Convenience method to internally identify the column
        #
        # @note The column id is used to find its help text in the {Y2Partitioner::Widgets::Help}
        #   module. Ideally, each column should have its own #help_text method but those texts still
        #   being shared with the device overview (see {Y2Partitioner:: Widgets::DeviceDescription}.
        #
        # @return [Symbol] usually, the column type
        def id
          self.class.name
            .gsub(/^.*::/, "") # demodulize
            .gsub(/(.)([A-Z])/, '\1_\2') # underscore
            .downcase.to_sym
        end

        private

        def left_to_right(path_string)
          pn = Pathname.new(path_string)
          Bidi.pathname_bidi_to_s(pn)
        end

        # Helper method to create a `cell` term
        #
        # @param args [Array] content of the cell
        # @return [Yast::Term]
        def cell(*args)
          Yast::Term.new(:cell, *args.compact)
        end

        # Helper method to create a `sortKey` term
        #
        # @param value [String] a value to be used as a sort key
        # @return [Yast::Term]
        def sort_key(value)
          Yast::Term.new(:sortKey, value)
        end

        # @return [Y2Storage::Devicegraph]
        def system_graph
          DeviceGraphs.instance.system
        end

        # Returns the filesystem for the given device, when possible
        #
        # @return [Y2Storage::Filesystems::Base, nil]
        def filesystem_for(device)
          if device.is?(:filesystem)
            device
          elsif device.respond_to?(:filesystem)
            device.filesystem
          end
        end

        # Whether the device belongs to a multi-device filesystem
        #
        # @param device [Device]
        # @return [Boolean]
        def part_of_multidevice?(device, filesystem)
          return false unless device.is?(:blk_device)

          filesystem.multidevice?
        end

        # Determines if given device is actually an fstab entry
        #
        # @return [Boolean]
        def fstab_entry?(device)
          device.is_a?(Y2Storage::SimpleEtcFstabEntry)
        end
      end
    end
  end
end
