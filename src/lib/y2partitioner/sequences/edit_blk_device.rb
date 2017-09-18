require "yast"
require "ui/sequence"
require "y2partitioner/device_graphs"
require "y2partitioner/dialogs/partition_size"
require "y2partitioner/dialogs/partition_type"
require "y2partitioner/dialogs/encrypt_password"
require "y2partitioner/dialogs/format_and_mount"
require "y2partitioner/format_mount/base"

Yast.import "Popup"
Yast.import "Wizard"

module Y2Partitioner
  module Sequences
    # BlkDevice edition
    class EditBlkDevice < UI::Sequence
      include Yast::Logger
      # @param partition [Y2Storage::BlkDevice]
      def initialize(blk_device)
        textdomain "storage"
        @fs_controller = FilesystemController.new(blk_device)
      end

      def run
        sequence_hash = {
          "ws_start"       => "preconditions",
          "preconditions"  => { next: "format_options" },
          "format_options" => { next: "password" },
          "password"       => { next: "commit" },
          "commit"         => { finish: :finish }
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
        if blk_device.is?(:partition) && blk_device.type.is?(:extended)
          Yast::Popup.Error(_("An extended partition cannot be edited"))
          :back
        else
          :next
        end
      end
      skip_stack :preconditions

      def format_options
        Dialogs::FormatAndMount.run(fs_controller)
      end

      def password
        return :next unless fs_controller.to_be_encrypted?
        Dialogs::EncryptPassword.run(fs_controller)
      end

      def commit
        fs_controller.finish
        :finish
      end

    private

      attr_reader :fs_controller

      def blk_device
        fs_controller.blk_device
      end
    end
  end
end
