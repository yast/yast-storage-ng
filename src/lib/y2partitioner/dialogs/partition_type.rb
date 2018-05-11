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
require "cwm/common_widgets"
require "y2partitioner/dialogs/base"

module Y2Partitioner
  module Dialogs
    # Determine the type (primary/extended/logical)
    # of a partition to be created.
    # Part of {Actions::AddPartition}.
    # Formerly MiniWorkflowStepPartitionType
    class PartitionType < Base
      # Choose partition type: primary/extended/logical.
      class TypeChoice < CWM::RadioButtons
        # @param controller [Actions::Controllers::Partition]
        def initialize(controller)
          textdomain "storage"
          @controller = controller
          @slots = controller.unused_optimal_slots
        end

        # @macro seeAbstractWidget
        def label
          _("New Partition Type")
        end

        # @macro seeAbstractWidget
        def help
          # helptext
          _("<p>Choose the partition type for the new partition.</p>")
        end

        def items
          available_types = Y2Storage::PartitionType.all.map do |ty|
            [ty.to_s, !@slots.find { |s| s.possible?(ty) }.nil?]
          end.to_h

          [
            # radio button text
            ["primary", _("&Primary Partition")],
            # radio button text
            ["extended", _("&Extended Partition")],
            # radio button text
            ["logical", _("&Logical Partition")]
          ].find_all { |t, _l| available_types[t] }
        end

        # @macro seeAbstractWidget
        def validate
          !value.nil?
        end

        # @macro seeAbstractWidget
        def init
          # Pick the first one available
          default_pt = Y2Storage::PartitionType.new(items.first.first)
          self.value = (@controller.type ||= default_pt).to_s
        end

        # @macro seeAbstractWidget
        def store
          @controller.type = Y2Storage::PartitionType.new(value)
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

      # Overwrite run. If there is only one type of partition, just select it
      def run
        case type_choice.items.size
        when 0
          raise "No partition type possible"
        when 1
          @controller.type = Y2Storage::PartitionType.new(type_choice.items.first.first)
          :next
        else
          super
        end
      end

    private

      def type_choice
        @type_choice ||= TypeChoice.new(@controller)
      end
    end
  end
end
