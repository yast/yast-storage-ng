require "y2storage"
require "yast"
require "cwm/dialog"
require "cwm/common_widgets"
require "cwm/custom_widget"
require "y2partitioner/widgets/controller_radio_buttons"

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Determine the size of a partition to be created, in the form
    # of a {Y2Storage::Region}.
    # Part of {Actions::AddPartition}.
    # Formerly MiniWorkflowStepPartitionSize
    class PartitionSize < CWM::Dialog
      # @param controller [Actions::Controllers::Partition]
      #   a partition controller, collecting data for a partition to be created
      def initialize(controller)
        textdomain "storage"
        @disk_name = controller.disk_name
        @controller = controller
        @regions = controller.unused_slots.map(&:region)

        raise ArgumentError, "No region to make a partition in" if @regions.empty?
      end

      # @macro seeDialog
      def title
        @controller.wizard_title
      end

      # @macro seeDialog
      def contents
        HVSquash(SizeWidget.new(@controller, @regions))
      end

      # return finish for extended partition, as it can set only type and its size
      def run
        res = super
        res = :finish if res == :next && @controller.type.is?(:extended)
        res
      end

      # Choose a size (region, really) for a new partition
      # from several options: use maximum, enter size, enter start+end
      class SizeWidget < Widgets::ControllerRadioButtons
        # @param controller [Actions::Controllers::Partition]
        #   a controller collecting data for a partition to be created
        # @param regions [Array<Y2Storage::Region>]
        #   regions available to create a partition in
        def initialize(controller, regions)
          textdomain "storage"
          @controller = controller
          @regions = regions
          @largest_region = @regions.max_by(&:size)
        end

        # @macro seeAbstractWidget
        def label
          _("New Partition Size")
        end

        def items
          max_size_label = Yast::Builtins.sformat(_("Maximum Size (%1)"),
            @largest_region.size.human_floor)
          [
            [:max_size, max_size_label],
            [:custom_size, _("Custom Size")],
            [:custom_region, _("Custom Region")]
          ]
        end

        def widgets
          @widgets ||= [
            MaxSizeDummy.new(@largest_region),
            CustomSizeInput.new(@controller, @regions),
            CustomRegion.new(@controller, @regions)
          ]
        end

        # @macro seeAbstractWidget
        def init
          self.value = (@controller.size_choice ||= :max_size)
          # trigger disabling the other subwidgets
          handle("ID" => value)
        end

        # @macro seeAbstractWidget
        def store
          w = current_widget
          w.store
          @controller.region = w.region
          @controller.size_choice = value
        end
      end

      # An invisible widget that knows a Region
      class MaxSizeDummy < CWM::Empty
        attr_reader :region

        # @param region [Y2Storage::Region]
        def initialize(region)
          @region = region
        end

        # @macro seeAbstractWidget
        def store
          # nothing to do, that's OK
        end
      end

      # Enter a human readable size
      class CustomSizeInput < CWM::InputField
        # @return [Y2Storage::DiskSize]
        attr_reader :min_size, :max_size

        # @param controller [Actions::Controllers::Partition]
        #   a controller collecting data for a partition to be created
        # @param regions [Array<Y2Storage::Region>]
        #   regions available to create a partition in
        def initialize(controller, regions)
          textdomain "storage"
          @controller = controller
          @regions = regions
          largest_region = @regions.max_by(&:size)
          @max_size = largest_region.size
          @min_size = largest_region.block_size
        end

        # Forward to controller
        def size
          @controller.custom_size
        end

        # Forward to controller
        def size=(v)
          @controller.custom_size = v
        end

        # @return [Y2Storage::Region] the smallest region
        #   that can contain the chosen size
        def parent_region
          suitable_rs = @regions.find_all { |r| r.size >= size }
          suitable_rs.min_by(&:size)
        end

        # @return [Y2Storage::Region]
        # A new region created in the smallest region
        #   that can contain the chosen size
        def region
          parent = parent_region
          bsize = parent.block_size
          length = (size.to_i / bsize.to_i.to_f).ceil
          Y2Storage::Region.create(parent.start, length, bsize)
        end

        # @macro seeAbstractWidget
        def label
          _("Size")
        end

        # @macro seeAbstractWidget
        def init
          self.size ||= max_size
          self.value = size
        end

        # @macro seeAbstractWidget
        def store
          self.size = value
        end

        # @macro seeAbstractWidget
        def validate
          return true unless enabled?
          v = value
          return true unless v.nil? || v < min_size || v > max_size

          min_s = min_size.human_ceil
          max_s = max_size.human_floor
          Yast::Popup.Error(
            Yast::Builtins.sformat(
              # error popup, %1 and %2 are replaced by sizes
              _("The size entered is invalid. Enter a size between %1 and %2."),
              min_s, max_s
            )
          )
          # TODO: Let CWM set the focus
          Yast::UI.SetFocus(Id(widget_id))
          false
        end

        # @return [Y2Storage::DiskSize,nil]
        def value
          Y2Storage::DiskSize.from_human_string(super)
        rescue TypeError
          nil
        end

        # @param v [Y2Storage::DiskSize]
        def value=(v)
          super(v.human_floor)
        end
      end

      # Specify start+end of the region
      class CustomRegion < CWM::CustomWidget
        attr_reader :region

        # @param controller [Actions::Controllers::Partition]
        #   a controller collecting data for a partition to be created
        # @param regions [Array<Y2Storage::Region>]
        #   regions available to create a partition in
        def initialize(controller, regions)
          textdomain "storage"
          @controller = controller
          @regions = regions
          @region = @controller.region || @regions.max_by(&:size)
        end

        # @macro seeCustomWidget
        def contents
          min_block = @regions.map(&:start).min
          # FIXME: libyui widget overflow :-(
          max_block = @regions.map(&:end).max

          int_field = lambda do |id, label, val|
            MinWidth(
              10,
              IntField(Id(id), label, min_block, max_block, val)
            )
          end
          VBox(
            Id(widget_id),
            int_field.call(:start_block, _("Start Block"), region.start),
            int_field.call(:end_block, _("End Block"), region.end)
          )
        end

        # UI::QueryWidget both ids in one step
        def query_widgets
          [
            Yast::UI.QueryWidget(Id(:start_block), :Value),
            Yast::UI.QueryWidget(Id(:end_block), :Value)
          ]
        end

        # @macro seeAbstractWidget
        def store
          start_block, end_block = query_widgets
          len = end_block - start_block + 1
          bsize = @regions.first.block_size # where does this come from?
          @region = Y2Storage::Region.create(start_block, len, bsize)
        end

        # @macro seeAbstractWidget
        def validate
          return true unless enabled?

          start_block, end_block = query_widgets
          # starting block must be in a region,
          # ending block must be in the same region
          parent = @regions.find { |r| r.cover?(start_block) }
          return true if parent && parent.cover?(end_block)
          # TODO: a better description why
          # error popup
          Yast::Popup.Error(_("The region entered is invalid."))
          Yast::UI.SetFocus(Id(:start_block))
          false
        end
      end
    end
  end
end
