require "yast"
require "ui/sequence"
require "y2partitioner/device_graphs"

Yast.import "Wizard"

module Y2Partitioner
  module Sequences
    # Base class for the sequences that modify the devicegraph with a
    # transaction (most of the expert partitioner sequences)
    class TransactionWizard < UI::Sequence
      include Yast::Logger

      def initialize
        textdomain "storage"
      end

      # Main method of any UI::Sequence.
      #
      # See the associated documentation at yast2.
      def run
        sym = nil
        DeviceGraphs.instance.transaction do
          init_transaction

          sym = wizard_next_back do
            super(sequence: sequence_hash)
          end

          sym == :finish
        end
        sym
      end

    protected

      # Specification of the steps of the sequence.
      #
      # To be defined by each subclass.
      #
      # See UI::Sequence in yast2.
      def sequence_hash
        {}
      end

      # Method called after creating the devicegraphs transaction but before
      # starting the wizard.
      #
      # To be defined, if needed, by each subclass
      def init_transaction; end

      # FIXME: move to Wizard
      def wizard_next_back(&block)
        Yast::Wizard.OpenNextBackDialog
        block.call
      ensure
        Yast::Wizard.CloseDialog
      end
    end
  end
end
