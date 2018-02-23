# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

require "y2partitioner/widgets/device_description"

module Y2Partitioner
  module Widgets
    # Richtext filled with the description of a volume group
    #
    # The volume group is given during initialization (see {DeviceDescription}).
    class LvmVgDescription < DeviceDescription
      def initialize(*args)
        super
        textdomain "storage"
      end

      # A volume group description is composed by the header "Device" and a list
      # of attributes
      #
      # @see #lvm_vg_description
      #
      # @return [String]
      def device_description
        output = Yast::HTML.Heading(_("Device:"))
        output << Yast::HTML.List(device_attributes)
        output << lvm_vg_description
      end

      # Attributes for describing a device when it is a volume group
      #
      # @return [Array<String>]
      def device_attributes
        [
          format(_("Device: %s"), "/dev/" + device.vg_name),
          format(_("Size: %s"), device.size.to_human_string)
        ]
      end

      # Richtext description of a volume group
      #
      # A volume group description is composed by the header "LVM" and a list of attributes.
      #
      # @return [String]
      def lvm_vg_description
        # TRANSLATORS: heading for the section about a volume group
        output = Yast::HTML.Heading(_("LVM:"))
        output << Yast::HTML.List(lvm_vg_attributes)
      end

      # Attributes for describing a volume group
      #
      # @return [Array<String>]
      def lvm_vg_attributes
        [
          extent_size
        ]
      end

      # Information about the volume group extent size
      #
      # @return [String]
      def extent_size
        # TRANSLATORS: Volume group extent size information, where %s is replaced by
        # a size (e.g., 8 KiB)
        format(_("PE Size: %s"), device.extent_size.to_human_string)
      end

      # Fields to show in help
      #
      # @return [Array<Symbol>]
      def help_fields
        lvm_vg_help_fields
      end

      LVM_VG_HELP_FIELDS = [:device, :size, :pe_size].freeze

      # Help fields for a volume group
      #
      # @return [Array<Symbol>]
      def lvm_vg_help_fields
        LVM_VG_HELP_FIELDS.dup
      end
    end
  end
end
