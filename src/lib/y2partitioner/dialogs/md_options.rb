require "yast"
require "y2storage"
require "cwm/dialog"
require "cwm"

module Y2Partitioner
  module Dialogs
    # Form to set the chunk size and parity of an MD RAID
    # Part of {Actions::AddMd}.
    class MdOptions < CWM::Dialog
      # @param controller [Actions::Controllers::Md]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
        @chunk_size_selector = ChunkSize.new(controller)
        @parity_selector = controller.parity_supported? ? Parity.new(controller) : Empty()
      end

      # @macro seeDialog
      def title
        @controller.wizard_title
      end

      # @macro seeDialog
      def contents
        HVSquash(
          VBox(
            Left(@chunk_size_selector),
            Left(@parity_selector)
          )
        )
      end

    private

      attr_reader :controller

      # Widget to select the chunk size
      class ChunkSize < CWM::ComboBox
        # @param controller [Actions::Controllers::Md]
        def initialize(controller)
          textdomain "storage"
          @controller = controller
        end

        def label
          _("Chunk Size")
        end

        # @macro seeAbstractWidget
        def opt
          %i(hstretch notify)
        end

        def items
          SIZES.map { |s| [Y2Storage::DiskSize.new(s).to_s, s] }
        end

        # @macro seeAbstractWidget
        def init
          self.value = @controller.chunk_size.to_s
        end

        # @macro seeAbstractWidget
        def store
          @controller.chunk_size = Y2Storage::DiskSize.new(value)
        end

        SIZES = ["4 KiB", "8 KiB", "16 KiB", "32 KiB", "128 KiB",
                 "256 KiB", "512 KiB", "1 MiB", "2 MiB", "4 MiB"].freeze

        private_constant :SIZES
      end

      # Widget to select the md parity
      class Parity < CWM::ComboBox
        # @param controller [Actions::Controllers::Md]
        def initialize(controller)
          textdomain "storage"

          @controller = controller
        end

        def label
          _("Parity Algorithm")
        end

        # @macro seeAbstractWidget
        def opt
          %i(hstretch notify)
        end

        def items
          PARITIES.map { |p| [p.to_s, Y2Storage::MdParity.find(p).to_human_string] }
        end

        # @macro seeAbstractWidget
        def init
          self.value = @controller.md_parity.to_s
        end

        # @macro seeAbstractWidget
        def store
          @controller.md_parity = Y2Storage::MdParity.find(value)
        end

        PARITIES = [:default, :near_2, :offset_2, :far_2, :near_3, :offset_3, :far_3].freeze

        private_constant :PARITIES
      end
    end
  end
end
