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
require "ui/sequence"
require "y2partitioner/device_graphs"

Yast.import "Wizard"

module Y2Partitioner
  module Actions
    # Base class for the sequences that modify the devicegraph with a
    # transaction (most of the expert partitioner actions)
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

          sym =
            if run?
              wizard_next_back do
                super(sequence: sequence_hash)
              end
            else
              :back
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

      # Checks whether it makes sense to execute the sequence, reporting to the
      # user the possible reasons for not running it.
      #
      # To be defined, if needed, by each subclass.
      #
      # @return [Boolean]
      def run?
        true
      end
    end
  end
end
