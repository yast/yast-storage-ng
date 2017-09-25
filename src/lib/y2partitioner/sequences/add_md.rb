require "yast"
require "ui/sequence"
require "y2partitioner/device_graphs"
require "y2partitioner/sequences/md_controller"
require "y2partitioner/dialogs/md"
#require "y2partitioner/sequences/filesystem_controller"

Yast.import "Wizard"

module Y2Partitioner
  module Sequences
    # formerly EpCreateRaid
    class AddMd < UI::Sequence
      include Yast::Logger
      def initialize
        textdomain "storage"

        @md_controller = MdController.new
      end

      def run
        sequence_hash = {
          "ws_start"       => "preconditions",
          "preconditions"  => { next: "devices" },
          "devices"        => { next: :finish },
=begin
          "role"           => { next: "format_options" },
          "format_options" => { next: "password" },
          "password"       => { next: "commit" },
          "commit"         => { finish: :finish }
=end
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
        return :next unless md_controller.available_devices.empty?

        Yast::Popup.Error(
          _("There are not enough suitable unused devices to create a RAID.")
        )
        :back
      end
      skip_stack :preconditions

      def devices
        Dialogs::Md.run(md_controller)
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
        return :next unless fs_controller.to_be_encrypted?
        Dialogs::EncryptPassword.run(fs_controller)
      end

      def commit
        fs_controller.finish
        :finish
      end

    private

      attr_reader :md_controller, :fs_controller
    end
  end
end
