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

        # Name of the logical volume to create
        # @return [String]
        attr_accessor :lv_name

        # Selected lv type
        # @return [Y2Storage::LvType]
        attr_accessor :lv_type

        # Selected thin pool
        # @return [Y2Storage::LvmLv, nil] nil if lv type is not thin
        attr_accessor :thin_pool

        # @return [Symbol] :max_size or :custom_size
        attr_accessor :size_choice

        # Selected size
        # @return [Y2Storage::DiskSize]
        attr_accessor :size

        # Selected stripes number
        # @return [Integer]
        attr_accessor :stripes_number

        # Selected stripe size
        # @return [DiskSize]
        attr_accessor :stripes_size

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
          @lv = lv_type.is?(:thin) ? create_thin_lv : create_normal_or_pool_lv
          UIState.instance.select_row(@lv)
        end

        # Removes the previously created logical volume
        def delete_lv
          return if lv.nil?

          vg.delete_lvm_lv(lv)
          @lv = nil
        end

        # Logical volume type selected (or initially proposed)
        #
        # @see #default_lv_type
        #
        # @return [Y2Storage::LvType]
        def lv_type
          @lv_type ||= default_lv_type
        end

        # Size and stripes values depends on the selected lv type, so that values
        # should be restored after setting the lv type.
        def reset_size_and_stripes
          @size = default_size
          @size_choice = default_size_choice
          @stripes_number = nil
          @stripes_size = nil
        end

        # Whether the new logical volume can be formatted
        #
        # @note Thin pools cannot be formatted.
        #
        # @return [Boolean]
        def lv_can_be_formatted?
          return false if lv.nil?

          !lv.lv_type.is?(:thin_pool)
        end

        # Whether a new logical volume (normal or pool) can be added to the volume group
        #
        # @note A logical volume can be added if there is available free space in the
        #   volume group.
        #
        # @return [Boolean]
        def lv_can_be_added?
          free_extents > 0
        end

        # Whether there is some available thin pool in the volume group
        #
        # @return [Boolean]
        def thin_lv_can_be_added?
          !available_thin_pools.empty?
        end

        # All available thin pools in the volume group
        #
        # @return [Array<Y2Storage::LvmLv>]
        def available_thin_pools
          vg.thin_pool_lvm_lvs
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
        # @note The max size depends on the logical volume type.
        #
        # @see Y2Storage::LvmLv#max_size_for_lvm_lv
        # @see Y2Storage::LvmVg#max_size_for_lvm_lv
        #
        # @return [Y2Storage::DiskSize]
        def max_size
          if lv_type.is?(:thin)
            thin_pool.max_size_for_lvm_lv(lv_type)
          else
            vg.max_size_for_lvm_lv(lv_type)
          end
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

        # Errors in the candidate name for the LV
        #
        # @param name [String]
        # @return [Array<String>] empty when there is no error
        def name_errors(name)
          errors = []
          errors << empty_name_error(name)
          errors << name_size_error(name)
          errors << name_chars_error(name)
          errors << used_name_error(name)
          errors.compact
        end

        # Title to display in the dialogs during the process
        #
        # @return [String]
        def wizard_title
          # TRANSLATORS: dialog title. %s is a device name like /dev/vg0
          _("Add Logical Volume on %s") % vg_name
        end

      private

        # If only thin volumes can be created, it returns thin type. Otherwise, it
        # returns normal type.
        #
        # @return [Y2Storage::LvType]
        def default_lv_type
          return Y2Storage::LvType::THIN if !lv_can_be_added? && thin_lv_can_be_added?
          Y2Storage::LvType::NORMAL
        end

        # It returns custom size if the selected type is thin volume. Otherwise, it
        # returns max size.
        #
        # @return [Symbol] :max_size, :custom_size
        def default_size_choice
          lv_type.is?(:thin) ? :custom_size : :max_size
        end

        # It returns 2 GiB if the selected type is thin volume. Otherwise, default
        # size is not determined.
        #
        # @return [Y2Storage::DiskSize, nil]
        def default_size
          lv_type.is?(:thin) ? Y2Storage::DiskSize.GiB(2) : nil
        end

        # Creates a new thin logical volume with the stored values
        #
        # @return [Y2Storage::LvmLv]
        def create_thin_lv
          thin_pool.create_lvm_lv(lv_name, Y2Storage::LvType::THIN, size)
        end

        # Creates a new logical volume (normal or pool) with the stored values
        #
        # @return [Y2Storage::LvmLv]
        def create_normal_or_pool_lv
          lv = vg.create_lvm_lv(lv_name, lv_type, size)
          lv.stripes = stripes_number if stripes_number
          lv.stripe_size = stripes_size  if stripes_size
          lv
        end

        # Error when the given logical volume name is empty
        #
        # @return [String, nil] nil if the name is not empty
        def empty_name_error(name)
          return nil if name && !name.empty?

          # TRANSLATORS: Error message when there is no name for the new logical volume
          _("Enter a name for the logical volume.")
        end

        # Error when the logical volume name is too long
        #
        # @return [String, nil] nil if the name size is correct
        def name_size_error(name)
          return nil if name.nil? || name.size <= 128

          # TRANSLATORS: Error message when the name of the logical volume is too long
          _("The name for the logical volume is longer than 128 characters.")
        end

        # Error when the logical volume name is composed by illegal characters
        #
        # @return [String, nil] nil if the name only has valid characters
        def name_chars_error(name)
          return nil if name.nil? || name.each_char.all? { |c| ALLOWED_CHARS.include?(c) }

          # TRANSLATORS: Error message when the name of the logical volume contains
          # illegal characters
          _("The name for the logical volume contains illegal characters.\n" \
             "Allowed are alphanumeric characters, \".\", \"_\", \"-\" and \"+\".")
        end

        # Error when the logical volume name is already used by other logical volume
        #
        # @see #lv_name_in_use?
        #
        # @return [String, nil] nil if the name is not used
        def used_name_error(name)
          return nil if name.nil? || !lv_name_in_use?(name)

          # TRANSLATORS: Error message when the name of the volume group is already used.
          # %{lv_name} is replaced by a logical volume name (e.g., lv1) and %{vg_name} is
          # replaced by a volume group name (e.g., system)
          format(
            _("A logical volume named \"%{lv_name}\" already exists\n" \
              "in volume group \"%{vg_name}\"."),
            lv_name: name, vg_name: vg_name
          )
        end

        # Whether the candidate name for the LV is already taken
        #
        # @note All logical volumes belonging to the volume group are taken into account,
        #   including thin volumes.
        #
        # @param name [String]
        # @return [Boolean]
        def lv_name_in_use?(name)
          vg.all_lvm_lvs.map(&:lv_name).any? { |n| n == name }
        end
      end
    end
  end
end
