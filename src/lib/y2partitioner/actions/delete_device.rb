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
require "yast/i18n"
require "y2partitioner/device_graphs"
require "y2partitioner/confirm_recursive_delete"
require "y2storage/filesystems/btrfs"
require "abstract_method"

Yast.import "Popup"
Yast.import "HTML"

module Y2Partitioner
  module Actions
    # Base class for the action to delete a device
    class DeleteDevice
      include Yast::Logger
      include Yast::I18n
      include Yast::UIShortcuts
      include ConfirmRecursiveDelete

      # Constructor
      # @param device [Y2Storage::Device]
      def initialize(device)
        textdomain "storage"

        @device = device
      end

      # Checks whether delete action can be performed and if so,
      # a confirmation popup is shown.
      #
      # @note Delete action and refresh for shadowing of BtrFS subvolumes
      #   are only performed when user confirms.
      #
      # @see Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing
      #
      # @return [Symbol, nil]
      def run
        return :back unless validate && confirm
        delete
        Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing(device_graph)

        :finish
      end

    private

      # @return [Y2Storage::Device] device to delete
      attr_reader :device

      # Current devicegraph
      #
      # @return [Y2Storage::Devicegraph]
      def device_graph
        DeviceGraphs.instance.current
      end

      # Deletes the indicated device
      #
      # @note Derived classes should implement this method.
      abstract_method :delete

      # Validations before performing the delete action
      #
      # @return [Boolean]
      def validate
        true
      end

      # Confirmation message before performing the delete action
      def confirm
        Yast::Popup.YesNo(
          # TRANSLATORS %s is the name of the device to be deleted (e.g., /dev/sda1)
          format(_("Really delete %s?"), device.name)
        )
      end

      # Checks whether the device is used as physical volume
      #
      # @return [Boolean] true if device belongs to a volume group; false otherwise
      def used_by_lvm?
        !lvm_vg.nil?
      end

      # Volume group that the device belongs to
      #
      # @see Y2Storage::BlkDevice#lvm_pv
      #
      # @return [Y2Storage::LvmVg, nil] nil if the device does not belong to
      #   a volume group
      def lvm_vg
        return nil unless device.respond_to?(:lvm_pv)

        lvm_pv = device.lvm_pv
        lvm_pv ? lvm_pv.lvm_vg : nil
      end

      # Checks whether the device is used by a md raid
      #
      # @return [Boolean] true if device belongs to a md raid; false otherwise
      def used_by_md?
        !md.nil?
      end

      # Md Raid that the device belongs to
      #
      # @see Y2Storage::BlkDevice#md
      #
      # @return [Y2Storage::Md, nil] nil if the device does not belong to a md raid
      def md
        device.md
      end
    end
  end
end
