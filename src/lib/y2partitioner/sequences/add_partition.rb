require "yast"
require "ui/sequence"
require "y2partitioner/device_graphs"
require "y2partitioner/sequences/partition_controller"
require "y2partitioner/sequences/filesystem_controller"
require "y2partitioner/dialogs/partition_role"
require "y2partitioner/dialogs/partition_size"
require "y2partitioner/dialogs/partition_type"
require "y2partitioner/dialogs/encrypt_password"

Yast.import "Wizard"

module Y2Partitioner
  module Sequences
    # formerly EpCreatePartition, DlgCreatePartition
    class AddPartition < UI::Sequence
      include Yast::Logger
      # @param disk_name [String]
      def initialize(disk_name)
        textdomain "storage"

        @part_controller = PartitionController.new(disk_name)
      end

      def disk_name
        part_controller.disk_name
      end

      def run
        sequence_hash = {
          "ws_start"       => "preconditions",
          "preconditions"  => { next: "type" },
          "type"           => { next: "size" },
          "size"           => { next: "role", finish: :finish },
          "role"           => { next: "format_options" },
          "format_options" => { next: "password" },
          "password"       => { next: :finish, finish: :finish }
        }

        sym = nil
        DeviceGraphs.instance.transaction do
          sym = wizard_next_back do
            super(sequence: sequence_hash)
          end

          sym == :finish
        end
        sym
      end

      # FIXME: move to Wizard
      def wizard_next_back(&block)
        Yast::Wizard.OpenNextBackDialog
        block.call
      ensure
        Yast::Wizard.CloseDialog
      end

      def preconditions
        return :next if part_controller.new_partition_possible?

        Yast::Popup.Error(
          # TRANSLATORS: %s is a device name (e.g. "/dev/sda")
          _("It is not possible to create a partition on %s.") % disk_name
        )
        :back
      end
      skip_stack :preconditions

      def type
        Dialogs::PartitionType.run(part_controller)
      end

      def size
        part_controller.delete_partition
        result = Dialogs::PartitionSize.run(part_controller)
        part_controller.create_partition if [:next, :finish].include?(result)
        @fs_controller = FilesystemController.new(part_controller.partition) if result == :next
        result
      end

      def role
        result = Dialogs::PartitionRole.run(fs_controller)
        fs_controller.apply_role if result == :next
        result
      end

      skip_stack :role

      def format_options
        Dialogs::FormatAndMount.run(fs_controller)
      end

      def password
        result =
          if fs_controller.to_be_encrypted?
            Dialogs::EncryptPassword.run(fs_controller)
          else
            :finish
          end
        fs_controller.finish if [:next, :finish].include?(result)
        result
      end

    private

      attr_reader :part_controller, :fs_controller
    end
  end
end
