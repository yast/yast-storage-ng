# Copyright (c) [2019-2020] SUSE LLC
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
require "y2storage/encryption_type"
require "y2storage/encryption_processes/secure_key"
require "y2storage/encryption_processes/apqn"

module Y2Partitioner
  module Actions
    module Controllers
      # This class adds or removes an encryption layer on top of the block
      # device that has been edited by the given Filesystem controller.
      class Encryption < Base
        include Yast::Logger
        include Yast::I18n

        # Action to perform when {#finish} is called
        #
        # Possible values:
        # * :keep preserves the encryption layer from the system devicegraph
        # * :encrypt adds an encryption device or replaces the previously added one
        # * :remove ensures the block device will not be encrypted
        # * sanitize removes current encryption layer when it cannot be preserved, see
        #   {#sanitize_encryption}
        #
        # @return [Symbol] :keep, :encrypt, :remove or :sanitize
        attr_accessor :action

        # @return [Y2Storage::EncryptionMethod] Encryption method
        attr_accessor :method

        # @return [String] Password for the encryption device
        attr_accessor :password

        # Selected APQNs to generate a new secure key for pervasive encryption
        #
        # @return [Array<Y2Storage:.EncryptionProcesses::Apqn>]
        attr_accessor :apqns

        # @return [String] Label for the encryption device if the method supports setting one
        attr_accessor :label

        # @return [PbkdFunction] Password-based key derivation function (PBKDF) for the LUKS2 device
        attr_accessor :pbkdf

        # Contructor
        #
        # @param fs_controller [Filesystem] see {#fs_controller}
        def initialize(fs_controller)
          super()
          textdomain "storage"

          @fs_controller = fs_controller
          @action = actions.first
          @password = encryption&.password || ""
          @pbkdf = encryption&.pbkdf || PbkdFunction::PBKDF2
          @method = initial_method
          @apqns = initial_apqns
          @label = initial_label
        end

        # Whether the dialog to select and configure the action makes sense
        #
        # @return [Boolean]
        def show_dialog?
          can_change_encrypt? && fs_controller.encrypt
        end

        # Actions that make sense for the block device
        #
        # @see #action
        # @see #calculate_actions
        #
        # If there is more than one possible action, the user should be able to use the UI to select
        # which one to perform.
        #
        # @return [Array<Symbol>]
        def actions
          @actions ||= calculate_actions
        end

        # Whether there are more than one encryption methods available
        #
        # @return [Boolean] true when there are several encryption methods; false if
        #   there is only one
        def several_encrypt_methods?
          methods.size > 1
        end

        # Returns available encryption methods
        #
        # @return [Array<Y2Storage::EncryptionMethod>]
        def methods
          @methods ||=
            if swap?
              Y2Storage::EncryptionMethod.available
            else
              Y2Storage::EncryptionMethod.available.reject(&:only_for_swap?)
            end
        end

        # Applies last changes to the block device at the end of the wizard, which mainly means: sanitize
        # current encryption layer or perform the proper finish action to create or remove the encryption
        #
        # @see #sanitize_encryption
        # @see #perform_finish_action
        def finish
          if action == :sanitize
            sanitize_encryption
          elsif can_change_encrypt?
            perform_finish_action
          end
        ensure
          fs_controller.update_checkpoint
        end

        # Encryption device currently associated to the block device, if any
        #
        # @return [Y2Storage::Encryption, nil]
        def encryption
          blk_device.encryption
        end

        # Existing secure key for the encrypted device
        #
        # @return [Y2Storage::EncryptionProcesses::SecureKey, nil] nil if no secure key is associated to
        #   the device.
        def secure_key
          Y2Storage::EncryptionProcesses::SecureKey.for_device(blk_device)
        end

        # Currently available APQNs for generating a new secure key
        #
        # @return [Array<Y2Storage::EncryptionProcesses::Apqn>]
        def online_apqns
          @online_apqns ||= Y2Storage::EncryptionProcesses::Apqn.online
        end

        # Finds an online APQN by its name
        #
        # @param name [String] APQN name (e.g., "01.0001")
        # @return [Y2Storage::EncryptionProcesses::Apqn, nil]
        def find_apqn(name)
          online_apqns.find { |a| a.name == name }
        end

        # Tests the generation of a secure key
        #
        # Note that the command for generating a secure key might fail when the APQNs are not correctly
        # configured. An APQN without a master key makes the command to tail. All the APQNs used for
        # generating the secure key must have the same master key.
        #
        # @param apqns [Array<Y2Storage::EncryptionProcesses::Apqn>]
        # @return [String, nil] error message or nil if the secure key can be generated
        def test_secure_key_generation(apqns: [])
          key_name = "yast2_tmp_secure_key_test"

          begin
            key = Y2Storage::EncryptionProcesses::SecureKey.generate!(key_name, apqns: apqns)
          rescue Cheetah::ExecutionFailed => e
            return e.message
          end

          key.remove

          nil
        end

        # Title to display in the dialog during the process
        #
        # @return [String]
        def wizard_title
          title =
            if actions.include?(:keep)
              _("Encryption for %s")
            elsif new_encryption?
              _("Modify encryption of %s")
            else
              _("Encrypt %s")
            end

          format(title, blk_device.name)
        end

        private

        # @return [Filesystem] controller used to create or edit the block
        #   device that will be modified by this controller
        attr_reader :fs_controller

        # Initial encryption method
        #
        # Note that the encryption method used by the current encryption device might not be available.
        #
        # @return [Y2Storage::EncryptionMethod]
        def initial_method
          if methods.include?(encryption&.method)
            encryption.method
          else
            Y2Storage::EncryptionMethod::LUKS2
          end
        end

        # Currently used APQNs when the device is encrypted with pervasive encryption
        #
        # @return [Array<Y2Storage::EncryptionProcesses::Apqn>]
        def initial_apqns
          process = encryption&.encryption_process

          return [] unless process.respond_to?(:apqns)

          process.apqns
        end

        # Currently used label when the device is encrypted with an encryption method that
        # supports setting such a label
        #
        # @return [String, nil] nil if the method does not support setting a label
        def initial_label
          return nil unless encryption.respond_to?(:label)

          encryption.label
        end

        # Calculate actions that make sense for the block device
        #
        # @see #actions
        #
        # @return [Array<Symbol>]
        def calculate_actions
          return [:remove] unless fs_controller.encrypt

          if sanitize_encryption? && !show_dialog?
            [:sanitize]
          elsif can_keep?
            [:keep, :encrypt]
          else
            [:encrypt]
          end
        end

        # Whether the device will be used as swap
        #
        # @return [Boolean] true when the device will be used as swap; false otherwise
        def swap?
          filesystem&.type&.is?(:swap) && filesystem.mount_path == "swap"
        end

        # Plain block device being modified
        #
        # Note this is always the plain device, no matter if it is encrypted or
        # not.
        #
        # @return [Y2Storage::BlkDevice]
        def blk_device
          fs_controller.blk_device
        end

        # Whether it's possible to remove or replace the encryption device
        # currently associated to the block device
        #
        # @return [Boolean] false if the device is formatted in the system and
        #   the user wants to preserve that filesystem
        def can_change_encrypt?
          filesystem.nil? || new?(filesystem)
        end

        # Filesystem from the plain block device
        #
        # @return [Y2Storage::Filesystem, nil] nil if the plain block device is not formatted
        def filesystem
          blk_device.filesystem
        end

        # Performs the proper action (create or delete the encryption)
        #
        # @note Unused LvmPv descendant are removed (bsc#1129663)
        #
        # @see #finish_encrypt
        # @see #finish_remove
        def perform_finish_action
          remove_unused_lvm_pv

          return if action == :keep

          if action == :encrypt
            finish_encrypt
          else
            finish_remove
          end

          adjust_mount_point
          encryption&.update_etc_status
        end

        # Sanitizes (removes) the encryption layer when needed
        #
        # Note that the filesystem is also deleted when it exists on disk (see {#can_change_encrypt?}).
        #
        # @see #sanitize_encryption?
        def sanitize_encryption
          return unless sanitize_encryption?

          if can_change_encrypt?
            blk_device.remove_encryption
          else
            blk_device.remove_descendants
          end
        end

        # Whether the current encryption layer should be removed
        #
        # Basically, when an original swap device was encrypted with an encryption method that is only
        # available for swap but the device is not used as swap anymore.
        #
        # @return [Boolean]
        def sanitize_encryption?
          return false unless blk_device.encrypted?

          !swap? && encryption.method&.only_for_swap?
        end

        # Removes from the block device or its encryption layer a LvmPv not associated to an LvmVg
        # (bsc#1129663)
        def remove_unused_lvm_pv
          device = encryption || blk_device
          lvm_pv = device.lvm_pv

          device.remove_descendants if lvm_pv&.descendants&.none?
        end

        # @see #finish
        def finish_remove
          return unless blk_device.encrypted?

          blk_device.remove_encryption
        end

        # @see #finish
        def finish_encrypt
          blk_device.remove_encryption if blk_device.encrypted?
          blk_device.encrypt(
            method: method, password: password, apqns: apqns, label: label, pbkdf: pbkdf
          )
        end

        # Whether the block device is associated to an encryption device that
        # does not exists in the system yet
        #
        # In other words, if the device is going to be (re)encrypted
        #
        # @return [Boolean]
        def new_encryption?
          blk_device.encrypted? && new?(encryption)
        end

        # Whether it makes sense to offer the :keep action
        #
        # @return [Boolean]
        def can_keep?
          return false unless blk_device.encrypted?
          return false if new?(encryption)
          return false if sanitize_encryption?

          encryption.active?
        end

        # Adjusts the properties of the mount point after having added or
        # removed the encryption device
        def adjust_mount_point
          mp = filesystem&.mount_point
          return if mp.nil?

          mp.set_default_mount_by unless mp.manual_mount_by?
          mp.ensure_suitable_mount_by
        end
      end
    end
  end
end
