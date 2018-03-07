require "y2storage"
require "yast"
require "cwm/dialog"
require "cwm/custom_widget"
require "cwm/common_widgets"
require "y2partitioner/widgets/controller_radio_buttons"
require "y2partitioner/device_graphs"
require "y2partitioner/size_parser"

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Dialog to set the new size for a partition or LVM LV
    class BlkDeviceResize < CWM::Dialog
      # Constructor
      #
      # @param device [Y2Storage::Partition, Y2Storage::LvmLv] device to resize
      def initialize(device)
        textdomain "storage"

        @device = device
        detect_space_info
      end

      # @macro seeDialog
      def title
        # TRANSLATORS: dialog title, where %{name} is the name of a partition
        # (e.g. /dev/sda1) or LVM logical volume (e.g. /dev/system/home)
        format(_("Resize %{name}"), name: device.name)
      end

      # @macro seeDialog
      def contents
        HVSquash(
          VBox(
            SizeSelector.new(device),
            size_info
          )
        )
      end

      # @macro seeDialog
      def run
        res = super

        # TODO: check mount

        res
      end

      # @macro seeDialog
      # Necessary to mimic wizard dialog layout and behaviour
      def should_open_dialog?
        true
      end

    private

      # @return [Y2Storage::Partition, Y2Storage::LvmLv]
      attr_reader :device

      # @return [Y2Storage::SpaceInfo]
      attr_reader :space_info

      def detect_space_info
        return unless formatted? && committed_device? && !swap?
        @space_info = device.filesystem.detect_space_info
      end

      # Whether the device is formatted
      #
      # @return [Boolean]
      def formatted?
        device.formatted?
      end

      # Whether the device exists on the system
      #
      # @return [Boolean] true if the device exists on disk; false otherwise.
      def committed_device?
        system = DeviceGraphs.instance.system
        device.exists_in_devicegraph?(system)
      end

      # Whether the device is for swap
      #
      # @return [Boolean]
      def swap?
        return true if device.is?(:partition) && device.id.is?(:swap)
        device.formatted_as?(:swap)
      end

      # Disk size in use
      #
      # @note This value only makes sense if the device is formatted and committed.
      #
      # @return [Y2Storage::Disksize, nil] nil if it is not possible to detect its
      #   space info.
      def used_size
        return nil if space_info.nil?
        space_info.used
      end

      # Widgets to show size info of the device (current and used sizes)
      #
      # @note Used size is only shown if space info can be detected.
      def size_info
        widgets = []
        widgets << current_size_info
        widgets << used_size_info unless space_info.nil?
        VBox(*widgets)
      end

      # Widget for current size
      def current_size_info
        size = device.size.to_human_string
        # TRANSLATORS: label for current size of the partition or LVM logical volume,
        # where %{size} is replaced by a size (e.g., 5.5 GiB)
        Left(Label(format(_("Current size: %{size}"), size: size)))
      end

      # Widget for used size
      def used_size_info
        size = used_size.to_human_string
        # TRANSLATORS: label for currently used size of the partition or LVM volume,
        # where %{size} is replaced by a size (e.g., 5.5 GiB)
        Left(Label(format(_("Currently used: %{size}"), size: size)))
      end
    end

    class BlkDeviceResize
      # Widget to select a new size
      #
      # @note The device is updated with the selected size.
      class SizeSelector < Widgets::ControllerRadioButtons
        # Constructor
        #
        # @param device [Y2Storage::Partition, Y2Storage::LvmLv]
        def initialize(device)
          textdomain "storage"

          @device = device
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
            BlkDeviceResize::FixedSizeWidget.new(max_size),
            BlkDeviceResize::FixedSizeWidget.new(min_size),
            BlkDeviceResize::CustomSizeWidget.new(min_size, max_size, current_size)
          ]
        end

        # @macro seeAbstractWidget
        def init
          self.value = :max_size
          # trigger disabling the other subwidgets
          handle("ID" => value)
        end

        # @macro seeAbstractWidget
        # Updates the device with the new size
        def store
          device.resize(current_widget.size)
          show_warnings
        end

        # @macro seeAbstractWidget
        def help
          _("<p>Choose new size.</p>")
        end

        # @macro seeAbstractWidget
        # Whether the indicated value is valid. It must be a disk size
        # between min and max possible sizes.
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

        # @return [Y2Storage::Partition, Y2Storage::LvmLv]
        attr_reader :device

        # Resize information of the device to be resized
        #
        # @return [Y2Storage::ResizeInfo]
        def resize_info
          device.resize_info
        end

        # Min possible size
        #
        # @return [Y2Storage::DiskSize]
        def min_size
          min =
            if device.respond_to?(:aligned_min_size)
              device.aligned_min_size
            else
              resize_info.min_size
            end
          [min, device.size].min
        end

        # Max possible size
        #
        # @return [Y2Storage::DiskSize]
        def max_size
          resize_info.max_size
        end

        # Current device size
        #
        # @return [Y2Storage::DiskSize]
        def current_size
          device.size
        end

        # Shows warning messages after setting the new size
        #
        # @see #overcommitted_thin_pool_warning
        def show_warnings
          overcommitted_thin_pool_warning
        end

        # Warning when the resizing device is an LVM thin pool and it is overcommitted
        def overcommitted_thin_pool_warning
          return unless overcommitted_thin_pool?

          total_thin_size = Y2Storage::DiskSize.sum(device.lvm_lvs.map(&:size))

          Yast::Popup.Warning(
            format(
              _("The LVM thin pool %{name} is overcomitted "\
                "(needs %{total_thin_size} and only has %{size}).\n" \
                "It might not have enough space for some LVM thin volumes."),
              name:            device.name,
              size:            device.size.to_human_string,
              total_thin_size: total_thin_size.to_human_string
            )
          )
        end

        # Whether the device is an overcommitted thin pool
        #
        # @return [Boolean]
        def overcommitted_thin_pool?
          return false unless device.is?(:lvm_lv)
          device.overcommitted?
        end
      end
    end

    class BlkDeviceResize
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

    class BlkDeviceResize
      # Widget to enter a human readable size
      class CustomSizeWidget < CWM::InputField
        include SizeParser

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
          parse_user_size(super)
        end

        alias_method :size, :value

        # @param v [Y2Storage::DiskSize]
        def value=(v)
          super(v.to_human_string)
        end
      end
    end
  end
end
