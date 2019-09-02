# Copyright (c) [2019] SUSE LLC
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

require "y2storage"
require "y2partitioner/actions/controllers/base"

module Y2Partitioner
  module Actions
    module Controllers
      # This class adds or removes an encryption layer on top of the block
      # device that has been edited by the given Filesystem controller.
      class Encryption < Base
        include Yast::Logger

        # @return [String] Password for the encryption device
        attr_accessor :encrypt_password

        # Contructor
        #
        # @param fs_controller [Filesystem] see {#fs_controller}
        def initialize(fs_controller)
          super()
          @fs_controller = fs_controller
        end

        # Whether a new encryption device will be created for the block device
        #
        # @return [Boolean]
        def to_be_encrypted?
          return false unless can_change_encrypt?

          fs_controller.encrypt && !blk_device.encrypted?
        end

        # Applies last changes to the block device at the end of the wizard, which
        # mainly means
        #
        #   * removing unused LvmPv descendant (bsc#1129663)
        #   * encrypting the device or removing the encryption layer.
        def finish
          return unless can_change_encrypt?

          remove_unused_lvm_pv

          if to_be_encrypted?
            blk_device.encrypt(password: encrypt_password)
          elsif blk_device.encrypted? && !fs_controller.encrypt
            blk_device.remove_encryption
          end
        ensure
          fs_controller.update_checkpoint
        end

        # Name of the plain device
        #
        # @return [String]
        def blk_device_name
          blk_device.name
        end

        private

        # @return [Filesystem] controller used to create or edit the block
        #   device that will be modified by this controller
        attr_reader :fs_controller

        # Plain block device being modified
        #
        # Note this is always the plain device, no matter if it is encrypted or
        # not.
        #
        # @return [Y2Storage::BlkDevice]
        def blk_device
          fs_controller.blk_device
        end

        def can_change_encrypt?
          blk_device.filesystem.nil? || new?(blk_device.filesystem)
        end

        # Removes from the block device or its encryption layer a LvmPv not associated to an LvmVg
        # (bsc#1129663)
        def remove_unused_lvm_pv
          device = blk_device.encryption || blk_device
          lvm_pv = device.lvm_pv

          device.remove_descendants if lvm_pv&.descendants&.none?
        end
      end
    end
  end
end
