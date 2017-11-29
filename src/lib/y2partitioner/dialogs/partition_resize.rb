require "y2storage"
require "yast"
require "cwm/dialog"
require "cwm/custom_widget"
require "cwm/common_widgets"
require "y2partitioner/widgets/controller_radio_buttons"
require "y2partitioner/device_graphs"

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Dialog to set new partition size
    class PartitionResize < CWM::Dialog
      # Constructor
      #
      # @param partition [Y2Storage::Partition] partition to resize
      def initialize(partition)
        textdomain "storage"

        @partition = partition
        @space_info = partition.filesystem.detect_space_info if committed_partition?
      end

      # @macro seeDialog
      def title
        # TRANSLATORS: dialog title, where %{name} is the name of a partition (e.g., /dev/sda)
        format(_("Resize Partition %{name}"), name: partition.name)
      end

      # @macro seeDialog
      def contents
        HVSquash(
          VBox(
            SizeSelector.new(partition),
            size_info
          )
        )
      end

      # @macro seeDialog
      def run
        res = super

        # TODO: Check mount

        res
      end

      # @macro seeDialog
      # Necessary to mimic a wizard dialog layout and behaviour
      def should_open_dialog?
        true
      end

    private

      # @return [Y2Storage::Partition]
      attr_reader :partition

      # @return [Y2Storage::SpaceInfo]
      attr_reader :space_info

      # Disk size in use
      #
      # @note This value only makes sense if the partitions is committed.
      #
      # @return [Y2Storage::Disksize, nil] nil if the partition does not exist
      #   on disk.
      def used_size
        return nil unless committed_partition?
        space_info.used
      end

      # Whether the partition exists on disk
      #
      # @return [Boolean] true if the partition exists on disk; false otherwise.
      def committed_partition?
        system = DeviceGraphs.instance.system
        partition.exists_in_devicegraph?(system)
      end

      # Widgets to show size info of the partition (current and used sizes)
      #
      # @note Used size is only shown if the partition exists on disk.
      def size_info
        widgets = []
        widgets << current_size_info
        widgets << used_size_info if committed_partition?
        VBox(*widgets)
      end

      # Widget for current size
      def current_size_info
        size = partition.size.to_human_string
        Left(Label(format("Current size: %{size}", size: size)))
      end

      # Widget for used size
      def used_size_info
        size = used_size.to_human_string
        Left(Label(format("Currently used: %{size}", size: size)))
      end
    end

    class PartitionResize
      # Widget to select a new partition size
      #
      # @note The partition is updated with the selected size.
      class SizeSelector < Widgets::ControllerRadioButtons
        def initialize(partition)
          textdomain "storage"

          @partition = partition
          @resize_info = partition.detect_resize_info
        end

        # @macro seeAbstractWidget
        def label
          _("Size")
        end

        # @see Widgets::ControllerRadioButtons
        def items
          max_size_label = format(_("Maximum Size (%{size})"), size: max_size.to_human_string)
          min_size_label = format(_("Minimum Size (%{size})"), size: min_size.to_human_string)
          [
            [:max_size, max_size_label],
            [:min_size, min_size_label],
            [:custom_size, _("Custom Size")]
          ]
        end

        # @see Widgets::ControllerRadioButtons
        def widgets
          @widgets ||= [
            PartitionResize::FixedSizeWidget.new(max_size),
            PartitionResize::FixedSizeWidget.new(min_size),
            PartitionResize::CustomSizeWidget.new(min_size, max_size, current_size)
          ]
        end

        # @macro seeAbstractWidget
        def init
          self.value = :max_size
          # trigger disabling the other subwidgets
          handle("ID" => value)
        end

        # @macro seeAbstractWidget
        # Updates the partition with the new size
        def store
          partition.size = current_widget.size
        end

        # @macro seeAbstractWidget
        def help
          _("<p>Choose new size.</p>")
        end

        # @macro seeAbstractWidget
        # Whether the indicated value is valid
        # It must be a disk size between min and max possible sizes.
        #
        # @note An error popup is shown when the given size is not valid.
        #
        # @return [Boolean] true if the given size is valid; false otherwise.
        def validate
          v = current_widget.size
          return true unless v.nil? || v < min_size || v > max_size

          min_s = min_size.human_ceil
          max_s = max_size.human_floor
          Yast::Popup.Error(
            format(
              # TRANSLATORS: error popup message, where %{min} and %{max} are replaced by sizes.
              _("The size entered is invalid. Enter a size between %{min} and %{max}."),
              min: min_s,
              max: max_s
            )
          )
          Yast::UI.SetFocus(Id(widgets.last.widget_id))
          false
        end

      private

        # @return [Y2Storage::Partition]
        attr_reader :partition

        # @return [Y2Storage::ResizeInfo]
        attr_reader :resize_info

        # Min possible size
        #
        # @return [Y2Partition::DiskSize]
        def min_size
          resize_info.min_size
        end

        # Max possible size
        #
        # @return [Y2Partition::DiskSize]
        def max_size
          resize_info.max_size
        end

        # Current partition size
        #
        # @return [Y2Partition::DiskSize]
        def current_size
          partition.size
        end
      end
    end

    class PartitionResize
      # An invisible widget that knows a fixed size
      class FixedSizeWidget < CWM::Empty
        # @return [Y2Storage::DiskSize]
        attr_reader :size

        # Constructor
        #
        # @param size [Y2Storage::DiskSize]
        def initialize(size)
          @size = size
        end

        # @macro seeAbstractWidget
        def store
          # nothing to do, that's OK
        end
      end
    end

    class PartitionResize
      # Widget to enter a human readable size
      class CustomSizeWidget < CWM::InputField
        # @return [Y2Storage::DiskSize]
        attr_reader :min_size

        # @return [Y2Storage::DiskSize]
        attr_reader :max_size

        # @return [Y2Storage::DiskSize]
        attr_reader :current_size

        # Constructor
        #
        # @param min_size [Y2Storage::DiskSize]
        # @param max_size [Y2Storage::DiskSize]
        # @param current_size [Y2Storage::DiskSize]
        def initialize(min_size, max_size, current_size)
          textdomain "storage"

          @min_size = min_size
          @max_size = max_size
          @current_size = current_size
        end

        # @macro seeAbstractWidget
        def label
          _("Size")
        end

        # @macro seeAbstractWidget
        def init
          self.value = current_size
        end

        # @macro seeAbstractWidget
        def store
          # nothing to do, that's OK
        end

        # @return [Y2Storage::DiskSize, nil] nil if the given size is not human readable.
        def value
          Y2Storage::DiskSize.from_human_string(super)
        rescue TypeError
          nil
        end

        alias_method :size, :value

        # @param v [Y2Storage::DiskSize]
        def value=(v)
          super(v.human_floor)
        end
      end
    end
  end
end
