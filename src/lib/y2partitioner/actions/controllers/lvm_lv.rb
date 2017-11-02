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

require "yast"
require "y2storage"
require "y2partitioner/device_graphs"
require "y2partitioner/ui_state"

module Y2Partitioner
  module Actions
    module Controllers
      # This class stores information about a future LVM logical volume and
      # takes care of creating it on the devicegraph when needed.
      class LvmLv
        include Yast::I18n

        # Characters accepted as part of a LV name
        ALLOWED_CHARS =
          "0123456789" \
          "ABCDEFGHIJKLMNOPQRSTUVWXYZ" \
          "abcdefghijklmnopqrstuvwxyz" \
          "._-+"
        private_constant :ALLOWED_CHARS

        # @return [Symbol] :max_size or :custom_size
        attr_accessor :size_choice

        # Selected size
        # @return [Y2Storage::DiskSize]
        attr_accessor :size

        # @return [Symbol] :normal, :thin_pool, :thin
        attr_accessor :type_choice

        # Name of the selected thin pool (when type is :thin)
        # @return [String, nil]
        attr_accessor :thin_pool

        # Selected stripes number
        # @return [Integer]
        attr_accessor :stripes_number

        # Selected stripe size
        # @return [DiskSize]
        attr_accessor :stripes_size

        # Name of the logical volume to create
        # @return [String]
        attr_accessor :lv_name

        # New logical volume created by the controller.
        #
        # Nil if #create_lv has not beeing called or if the volume was
        # removed with #delete_lv.
        #
        # @return [Y2Storage::LvmLv, nil]
        attr_reader :lv

        # Name of the LVM volume group to create the LV in
        # @return [String]
        attr_reader :vg_name

        # Constructor
        #
        # @param vg [Y2Storage::LvmVg] see {#vg}
        def initialize(vg)
          textdomain "storage"
          @vg_name = vg.vg_name
        end

        # LVM volume group to create the LV in
        # @return [Y2Storage::LvmVg]
        def vg
          dg = DeviceGraphs.instance.current
          Y2Storage::LvmVg.find_by_vg_name(dg, vg_name)
        end

        # Creates the LV in the VG according to the controller attributes
        def create_lv
          @lv = vg.create_lvm_lv(lv_name, size)
          @lv.stripes = stripes_number if stripes_number
          @lv.stripe_size = stripes_size  if stripes_size
          UIState.instance.select_row(@lv)
        end

        # Removes the previously created logical volume
        def delete_lv
          return if lv.nil?

          vg.delete_lvm_lv(lv)
          @lv = nil
        end

        # Number of free extents in the volume group
        #
        # @return [Integer]
        def free_extents
          vg.number_of_free_extents
        end

        # Minimum size for the new LV
        #
        # @return [Y2Storage::DiskSize]
        def min_size
          vg.extent_size
        end

        # Maximum size for the new LV
        #
        # @return [Y2Storage::DiskSize]
        def max_size
          vg.available_space
        end

        # Possible stripe numbers for the new LV
        #
        # @note Stripes number options is a value from 1 to the number
        #   of physical volumes in the volume group.
        #
        # @return [Array<Integer>]
        def stripes_number_options
          pvs_size = vg.lvm_pvs.size
          return [] if pvs_size == 0

          (1..pvs_size).to_a
        end

        # Possible stripe sizes for the new LV
        #
        # @note Stripes size options is a power of two value from 4 KiB and
        #   the volume group extent size.
        #
        # @return [Array<DiskSize>]
        def stripes_size_options
          extent_size = vg.extent_size
          sizes = [Y2Storage::DiskSize.new("4 KiB")]

          loop do
            next_size = sizes.last * 2
            break if next_size > extent_size

            sizes << next_size
          end

          sizes
        end

        # Validates a candidate name for the LV
        #
        # @param name [String]
        # @return [String, nil] nil if the name is valid, an error string
        #   otherwise
        def error_for_lv_name(name)
          if name.size > 128
            _("The name for the logical volume is longer than 128 characters.")
          elsif name.each_char.any? { |c| !ALLOWED_CHARS.include?(c) }
            _(
              "The name for the logical volume contains illegal characters.\n" \
              "Allowed are alphanumeric characters, \".\", \"_\", \"-\" and \"+\"."
            )
          end
        end

        # Whether the candidate name for the LV is already taken
        #
        # @param name [String]
        # @return [Boolean]
        def lv_name_in_use?(name)
          vg.lvm_lvs.map(&:lv_name).any? { |n| n == name }
        end

        # Title to display in the dialogs during the process
        # @return [String]
        def wizard_title
          # TRANSLATORS: dialog title. %s is a device name like /dev/vg0
          _("Add Logical Volume on %s") % vg_name
        end
      end
    end
  end
end
