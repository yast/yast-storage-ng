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

require "y2partitioner/widgets/blk_device_description"
require "y2partitioner/widgets/lvm_lv_attributes"

module Y2Partitioner
  module Widgets
    # Richtext filled with the description of a logical volume
    #
    # The logical volume is given during initialization (see {BlkDeviceDescription}).
    class LvmLvDescription < BlkDeviceDescription
      alias_method :lvm_lv, :device

      include LvmLvAttributes

      def initialize(*args)
        super
        textdomain "storage"
      end

      # @see #blk_device_description
      # @see #lvm_lv_description
      # @see #filesystem_description
      #
      # @return [String]
      def device_description
        blk_device_description + lvm_lv_description + filesystem_description
      end

      # Attributes for describing a block device when it is a logical volume
      #
      # @return [Array<String>]
      def blk_device_attributes
        [
          device_name,
          device_size,
          device_encrypted
        ]
      end

      # Richtext description of a logical volume
      #
      # A logical volume description is composed by the header "LVM" and a list of attributes.
      #
      # @return [String]
      def lvm_lv_description
        output = Yast::HTML.Heading(_("LVM:"))
        output << Yast::HTML.List(lvm_lv_attributes)
      end

      # Attributes for describing a logical volume
      #
      # @return [Array<String>]
      def lvm_lv_attributes
        [
          device_stripes
        ]
      end

      # Fields to show in help
      #
      # @return [Array<Symbol>]
      def help_fields
        blk_device_help_fields + lvm_lv_help_fields + filesystem_help_fields
      end

      BLK_DEVICE_HELP_FIELDS = [:device, :size, :encrypted].freeze

      # Help fields for a block device when it is a logical volume
      #
      # @return [Array<Symbol>]
      def blk_device_help_fields
        BLK_DEVICE_HELP_FIELDS.dup
      end

      LVM_LV_HELP_FIELDS = [:stripes].freeze

      # Help fields for a logical volume
      #
      # @return [Array<Symbol>]
      def lvm_lv_help_fields
        LVM_LV_HELP_FIELDS.dup
      end
    end
  end
end
