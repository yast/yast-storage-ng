require "yast"
require "y2partitioner/actions/controllers/filesystem"
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
    # The class including the mixin can use {#new_blk_device_step1} and
    # {#new_blk_device_steps} to include the provided steps into its own
    # workflow. It must make sure #{fs_controller} is assigned before the
    # execution of those steps.
    #
    # @example
    #   class ExampleAction < TransactionWizard
    #     include NewBlkDevice
    #
    #     def first_step
    #       self.fs_controller = FilesystemController.new(whatever, "Title")
    #       :next
    #     end
    #
    #     def sequence_hash
    #       {
    #         "ws_start"   => "first_step",
    #         "first_step" => { next: new_blk_device_step1 }
    #       }.merge(new_blk_device_steps)
    #     end
    #   end
    module NewBlkDevice
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
      def new_blk_device_steps
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
      def new_blk_device_step1
        "filesystem_role"
      end
    end
  end
end
