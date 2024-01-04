# Copyright (c) [2017-2021] SUSE LLC
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

require "yast2/popup"
require "cwm/custom_widget"
require "cwm/common_widgets"
require "y2storage"
require "y2partitioner/dialogs/base"
require "y2partitioner/dialogs/unmount"
require "y2partitioner/widgets/controller_radio_buttons"
require "y2partitioner/size_parser"
require "y2partitioner/filesystem_errors"

module Y2Partitioner
  module Dialogs
    # Dialog to set the new size for a partition or LVM LV
    class BlkDeviceResize < Base
      # Constructor
      #
      # @param controller [Y2Partitioner::Actions::Controllers::BlkDevice] controller for a block device
      def initialize(controller)
        super()
        textdomain "storage"

        @controller = controller
        @device = controller.device

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
            size_selector,
            size_info
          )
        )
      end

      # @macro seeDialog
      # Necessary to mimic wizard dialog layout and behaviour
      def should_open_dialog?
        true
      end

      # Handler for "next" button
      #
      # It shows a dialog to unmount the device if required.
      #
      # @return [Boolean] see {#unmount}
      def next_handler
        unmount
      end

      private

      # @return [Y2Storage::Partition, Y2Storage::LvmLv]
      attr_reader :device

      # @return [Y2Partitioner::Actions::Controllers::BlkDevice] controller for a block device
      attr_reader :controller

      # @return [Y2Storage::SpaceInfo]
      attr_reader :space_info

      def detect_space_info
        return if controller.multidevice_filesystem? ||
          !controller.committed_current_filesystem? || swap?

        begin
          @space_info = device.filesystem.detect_space_info
        rescue Storage::Exception => e
          detect_space_info_failed_warning(e)
        end
      end

      # Show a warning popup about an error during detect_space_info.
      #
      # @param err [Storage::Exception] libstorage-ng exception for details
      def detect_space_info_failed_warning(err)
        log.warn "detect_space_info for #{device.name} failed: #{err.what}"

        # TRANSLATORS: Warning message when the user wanted to resize a filesystem
        # and there was a problem getting information about that filesystem.
        msg = _("Obtaining information about free space on this filesystem failed.\n" \
                "Resizing it might or might not work. If you continue, there is a risk\n" \
                "of losing all data on this filesystem.")
        Yast2::Popup.show(msg, headline: :warning, details: err.what, buttons: :ok)
      end

      # Whether the device is formatted
      #
      # @return [Boolean]
      def formatted?
        device.formatted?
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

      # Currently selected disk size
      #
      # @return [Y2Storage::DiskSize]
      def selected_size
        size_selector.current_widget.size
      end

      # Widget to select the new size
      #
      # @return [SizeSelector]
      def size_selector
        @size_selector ||= SizeSelector.new(device)
      end

      # Widgets to show size info of the device (current and used sizes)
      #
      # Used size is only shown if space info can be detected.
      #
      # @return [Array<CWM::WidgetTerm>]
      def size_info
        widgets = []
        widgets << current_size_info
        widgets << size_details_info
        widgets.compact!

        VBox(*widgets)
      end

      # Widget for current size
      #
      # @return [CWM::WidgetTerm]
      def current_size_info
        size = device.size.to_human_string
        # TRANSLATORS: label for current size of the partition or LVM logical volume,
        # where %{size} is replaced by a size (e.g., 5.5 GiB)
        Left(Label(format(_("Current size: %{size}"), size:)))
      end

      # Widget with more details about the size
      #
      # @return [CWM::WidgetTerm, nil] nil if there is no details to show
      def size_details_info
        multidevice_filesystem_info || used_size_info
      end

      # Widget with information when the device belongs to a multi-device filesystem
      #
      # @return [CWM::WidgetTerm, nil] nil if the device does not belong to a multi-device filesystem
      def multidevice_filesystem_info
        return nil unless controller.multidevice_filesystem?

        # TRANSLATORS: label when the device is used by a multi-device Btrfs, where %{btrfs} is replaced
        # by the display name of the filesystem (e.g., "Btrfs over 5 devices").
        Left(Label(format(_("Part of %{btrfs}"), btrfs: device.filesystem.display_name)))
      end

      # Widget for used size
      #
      # @return [CWM::WidgetTerm, nil] nil when used size cannot be calculated
      def used_size_info
        return nil unless space_info

        size = used_size.to_human_string
        # TRANSLATORS: label for currently used size of the partition or LVM volume,
        # where %{size} is replaced by a size (e.g., 5.5 GiB)
        Left(Label(format(_("Currently used: %{size}"), size:)))
      end

      # Tries to unmount the device, if required.
      #
      # @return [Boolean] true if it is not required to unmount or the device was correctly
      #   unmounted or the user decides to continue; false when the user cancels.
      def unmount
        return true unless mounted?

        try_unmount_for_shrinking &&
          try_unmount_for_growing &&
          try_unmount_for_big_growing
      end

      # Whether the filesystem exists on disk and it is mounted in the system
      #
      # @return [Boolean]
      def mounted?
        controller.committed_current_filesystem? &&
          controller.mounted_committed_filesystem?
      end

      # Tries to unmount when shrinking the device
      #
      # @return [Boolean] true if the device supports mounted shrinking or the device was
      #   correctly unmounted or user decides to continue; false if user cancels.
      def try_unmount_for_shrinking
        return true unless shrinking? && controller.unmount_for_shrinking?

        # TRANSLATORS: Note added to the dialog for trying to unmount a device
        note = _("It is not possible to shrink the file system while it is mounted.")

        Unmount.new(controller.committed_filesystem, note:).run == :finish
      end

      # Tries to unmount when growing the device
      #
      # @return [Boolean] true if the device supports mounted growing or the device was
      #   correctly unmounted or user decides to continue; false if user cancels.
      def try_unmount_for_growing
        return true unless growing? && controller.unmount_for_growing?

        # TRANSLATORS: Note added to the dialog for trying to unmount a device
        note = _("It is not possible to extend the file system while it is mounted.")

        Unmount.new(controller.committed_filesystem, note:).run == :finish
      end

      # Tries to unmount when performing big growing
      #
      # @return [Boolean] true if the device was correctly unmounted or user decides to
      #   continue; false if user cancels.
      def try_unmount_for_big_growing
        return true unless big_growing? && controller.mounted_committed_filesystem?

        # TRANSLATORS: %s is replaced by a number that represents the amount of GiB to extend (e.g., 56).
        note = format(
          _("You are extending a mounted filesystem by %s Gigabyte. \n" \
            "This may be quite slow and can take hours. You might possibly want \n" \
            "to consider umounting the filesystem, which will increase speed of \n" \
            "resize task a lot."),
          growing_size.to_i / Y2Storage::DiskSize.GiB(1).to_i
        )

        Unmount.new(controller.committed_filesystem, note:).run == :finish
      end

      # Whether the device is going to be shrunk
      #
      # @return [Boolean]
      def shrinking?
        selected_size < device.size
      end

      # Whether the device is going to be grown
      #
      # @return [Boolean]
      def growing?
        selected_size > device.size
      end

      # Whether the device is going to be grown more than 50 GiB
      #
      # @note Threshold to consider a big growing is defined in the old code, but there is not
      #   any kind of explanation:
      #   https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/ep-dialogs.rb#L1229
      #
      # @return [Boolean]
      def big_growing?
        growing? && growing_size > Y2Storage::DiskSize.GiB(50)
      end

      # How much the device is going to be grown
      #
      # @return [Y2Storage::DiskSize]
      def growing_size
        selected_size - device.size
      end
    end

    class BlkDeviceResize
      # Widget to select a new size
      #
      # @note The device is updated with the selected size.
      class SizeSelector < Widgets::ControllerRadioButtons
        include FilesystemErrors

        # Constructor
        #
        # @param device [Y2Storage::Partition, Y2Storage::LvmLv]
        def initialize(device)
          super()
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
          show_result_warnings
        end

        # @macro seeAbstractWidget
        def help
          _("<p>Choose new size.</p>")
        end

        # @macro seeAbstractWidget
        # Whether the given size is valid. It must be a size between the
        # min and max possible sizes.
        #
        # @note An error popup is shown when the given size is not valid.
        #   A warning popup is shown if there are some warnings.
        #
        # @see #errors
        # @see #validation_warnings
        #
        # @return [Boolean] true if there are no errors in the given size and
        #   the user decides to continue despite of the warnings (if any);
        #   false otherwise.
        def validate
          current_errors = errors
          current_warnings = validation_warnings

          return true if current_errors.empty? && current_warnings.empty?

          Yast::UI.SetFocus(Id(widgets.last.widget_id))

          if current_errors.any?
            message = current_errors.join("\n\n")
            Yast2::Popup.show(message, headline: :error)
            false
          else
            message = current_warnings
            message << _("Do you want to continue with the current setup?")
            message = message.join("\n\n")
            Yast2::Popup.show(message, headline: :warning, buttons: :yes_no) == :yes
          end
        end

        private

        # @return [Y2Storage::Partition, Y2Storage::LvmLv]
        attr_reader :device

        # Whether the device is a striped logical volume
        #
        # @return [Boolean]
        def striped_lv?
          device.is?(:lvm_lv) && device.striped?
        end

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
          striped_lv? ? max_size_for_striped_lv : resize_info.max_size
        end

        # Max size for a striped logical volume
        #
        # This is the maximum possible size, but nothing guarantees that the assigned physical volumes
        # have enough free extends to allocate it.
        #
        # @return [Y2Storage::DiskSize]
        def max_size_for_striped_lv
          [device.lvm_vg.max_size_for_striped_lv(device.stripes), resize_info.max_size].compact.min
        end

        # Current device size
        #
        # @return [Y2Storage::DiskSize]
        def current_size
          device.size
        end

        # Errors detected in the given size
        #
        # @see #size_limits_error
        #
        # @return [Array<String>]
        def errors
          [size_limits_error].compact
        end

        # Error when the given size is not between the allowed min and max values
        #
        # @return [String, nil] nil if the size is valid.
        def size_limits_error
          v = current_widget.size
          return nil if v && v >= min_size && v <= max_size

          min_s = min_size.human_ceil
          max_s = max_size.human_floor

          format(
            # TRANSLATORS: error popup message, where %{min} and %{max} are replaced by sizes.
            _("The size entered is invalid. Enter a size between %{min} and %{max}."),
            min: min_s,
            max: max_s
          )
        end

        # Warnings detected in the given size
        #
        # @see FilesystemValidation
        #
        # @return [Array<String>]
        def validation_warnings
          filesystem_errors(device.filesystem, new_size: current_widget.size)
        end

        # Shows warning messages after setting the new size
        #
        # @note A popup is shown with the warnings.
        #
        # @see #result_warnings
        def show_result_warnings
          warnings = result_warnings
          return if warnings.empty?

          message = warnings.join("\n\n")

          Yast2::Popup.show(message, headline: :warning)
        end

        # Warnings after saving the given new size
        #
        # @see #overcommitted_thin_pool_warning
        #
        # @return [Array<String>]
        def result_warnings
          [overcommitted_thin_pool_warning].compact
        end

        # Warning when the resizing device is an LVM thin pool and it is overcommitted
        #
        # @see #overcommitted_thin_pool?
        #
        # @return [String, nil] nil if the device is not a thin pool or it is not
        #   overcommitted.
        def overcommitted_thin_pool_warning
          return nil unless overcommitted_thin_pool?

          total_thin_size = Y2Storage::DiskSize.sum(device.lvm_lvs.map(&:size))

          format(
            _("The LVM thin pool %{name} is overcomitted " \
              "(needs %{total_thin_size} and only has %{size}).\n" \
              "It might not have enough space for some LVM thin volumes."),
            name:            device.name,
            size:            device.size.to_human_string,
            total_thin_size: total_thin_size.to_human_string
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
          super("__FixedSizeWidget")
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
          super()
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

        # @param disk_size [Y2Storage::DiskSize]
        def value=(disk_size)
          super(disk_size.to_human_string)
        end
      end
    end
  end
end
