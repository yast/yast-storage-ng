require "yast"
require "cwm/dialog"
require "cwm/common_widgets"

module Y2Partitioner
  module Dialogs
    # Determine the type (primary/extended/logical)
    # of a partition to be created.
    # Part of {Sequences::AddPartition}.
    # Formerly MiniWorkflowStepPartitionType
    class PartitionType < CWM::Dialog
      # Choose partition type: primary/extended/logical.
      class TypeChoice < CWM::RadioButtons
        # @param ptemplate [#type] a Y2Storage::PartitionType field
        def initialize(ptemplate, slots)
          textdomain "storage"
          @ptemplate = ptemplate
          @slots = slots
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
          self.value = (@ptemplate.type ||= default_pt).to_s
        end

        # @macro seeAbstractWidget
        def store
          @ptemplate.type = Y2Storage::PartitionType.new(value)
        end
      end

      # @param slots [Array<Y2Storage::PartitionTables::PartitionSlot>]
      def initialize(disk_name, ptemplate, slots)
        @disk_name = disk_name
        @ptemplate = ptemplate
        @slots = slots
        textdomain "storage"
      end

      # @macro seeDialog
      def title
        # dialog title
        Yast::Builtins.sformat(_("Add Partition on %1"), @disk_name)
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
          @ptemplate.type = Y2Storage::PartitionType.new(type_choice.items.first.first)
          :next
        else
          super
        end
      end

    private

      def type_choice
        @type_choice ||= TypeChoice.new(@ptemplate, @slots)
      end
    end
  end
end
