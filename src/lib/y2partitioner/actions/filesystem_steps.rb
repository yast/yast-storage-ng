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
require "y2partitioner/dialogs/partition_role"
require "y2partitioner/dialogs/format_and_mount"
require "y2partitioner/dialogs/encrypt_password"

Yast.import "Wizard"

module Y2Partitioner
  module Actions
    # Mixin for all those expert partitioner actions that create a block
    # device that can be formatted, mounted and/or encrypted at the end of the
    # sequence.
    #
    # The class including the mixin can use {#first_filesystem_step} and
    # {#filesystem_steps} to include the provided steps into its own
    # workflow. It must make sure #{fs_controller} is assigned before the
    # execution of those steps.
    #
    # @example
    #   class ExampleAction < TransactionWizard
    #     include FilesystemSteps
    #
    #     def first_step
    #       self.fs_controller = FilesystemController.new(whatever, "Title")
    #       :next
    #     end
    #
    #     def sequence_hash
    #       {
    #         "ws_start"   => "first_step",
    #         "first_step" => { next: first_filesystem_step }
    #       }.merge(filesystem_steps)
    #     end
    #   end
    module FilesystemSteps
      def self.included(base)
        base.skip_stack :filesystem_role
      end

      def filesystem_role
        result = Dialogs::PartitionRole.run(fs_controller)
        fs_controller.apply_role if result == :next
        result
      end

      def format_options
        Dialogs::FormatAndMount.run(fs_controller)
      end

      def encrypt_password
        return :next unless fs_controller.to_be_encrypted?
        Dialogs::EncryptPassword.run(fs_controller)
      end

      def filesystem_commit
        fs_controller.finish
        UIState.instance.select_row(fs_controller.blk_device)
        :finish
      end

    protected

      # Filesystem controller that must be instantiated at some point before
      # the provided steps are executed.
      # @return [Controllers::Filesystem]
      attr_accessor :fs_controller

      # Sequence steps provided by the mixin
      #
      # @return [Hash]
      def filesystem_steps
        {
          "filesystem_role"   => { next: "format_options" },
          "format_options"    => { next: "encrypt_password" },
          "encrypt_password"  => { next: "filesystem_commit" },
          "filesystem_commit" => { finish: :finish }
        }
      end

      # Name of the entry point step
      #
      # @see #new_blk_device_steps
      #
      # @return [String]
      def first_filesystem_step
        "filesystem_role"
      end
    end
  end
end
