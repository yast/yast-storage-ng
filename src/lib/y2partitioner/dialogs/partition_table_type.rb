require "yast"
require "cwm/dialog"
require "cwm/common_widgets"

module Y2Partitioner
  module Dialogs
    # Select a partition table type (GPT, MS-DOS, DASD)
    # Part of {Actions::CreatePartitionTable}.
    class PartitionTableType < CWM::Dialog
      # Choose partition table type
      class TypeChoice < CWM::RadioButtons
        # @param controller [Actions::Controllers::PartitionTable]
        def initialize(controller)
          textdomain "storage"

          @controller = controller
          @supported_types = controller.possible_partition_table_types.map(&:to_s)
          log.info("Supported partition table types: #{@supported_types}")
        end

        # @macro seeAbstractWidget
        def label
          _("New Partition Table Type")
        end

        # @macro seeAbstractWidget
        def help
          # helptext
          _("<p>Choose the partition table type for the new partition.</p>")
        end

        def items
          user_texts = {
            # radio button text for a partition table type
            "gpt"   => _("&GPT"),
            "msdos" => _("&MS-DOS (Classic PC Style)"),
            "dasd"  => _("&DASD")
          }

          @supported_types.map do |type|
            user_text = user_texts[type] || type
            [type, user_text]
          end
        end

        # @macro seeAbstractWidget
        def validate
          !value.nil?
        end

        # @macro seeAbstractWidget
        def init
          # Pick the first one available
          set_default
        end

        # @macro seeAbstractWidget
        def store
          @controller.type = Y2Storage::PartitionTables::Type.new(value)
        end

        def set_default
          @value = @supported_types.first
        end
      end

      # @param controller [Actions::Controllers::Partition]
      #   partition controller collecting data for a partition to be created
      def initialize(controller)
        @disk_name = controller.disk_name
        @controller = controller
        textdomain "storage"
      end

      # @macro seeDialog
      def title
        @controller.wizard_title
      end

      # @macro seeDialog
      def contents
        HVSquash(type_choice)
      end

    private

      def type_choice
        @type_choice ||= TypeChoice.new(@controller)
      end
    end
  end
end
