require "yast"
require "y2storage"
require "cwm"
require "y2partitioner/refinements/filesystem_type"
require "y2partitioner/dialogs/btrfs_subvolumes"
require "y2partitioner/widgets/fstab_options"
require "y2storage/mountable"
require "y2storage/btrfs_subvolume"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Format options for {Y2Storage::BlkDevice}
    #
    # This widget generates a Frame Term with the format and encrypt options,
    # redrawing the interface in case of filesystem or partition selection
    # change.
    class FormatOptions < CWM::CustomWidget
      # Constructor
      # @param controller [Actions::Controllers::Filesystem]
      # @param parent_widget [#refresh_others] container widget that must be
      #   notified after every relevant update to the controller information
      def initialize(controller, parent_widget)
        textdomain "storage"

        @controller        = controller
        @encrypt_widget    = EncryptBlkDevice.new(@controller)
        @filesystem_widget = BlkDeviceFilesystem.new(@controller)
        @format_options    = FormatOptionsArea.new(@controller)
        @partition_id      = PartitionId.new(@controller)
        @parent_widget     = parent_widget

        self.handle_all_events = true
      end

      # @macro seeAbstractWidget
      def init
        refresh
      end

      # Synchronize the widget with the information from the controller
      def refresh
        @encrypt_widget.refresh
        @filesystem_widget.refresh
        @partition_id.refresh
        @format_options.refresh

        if controller.to_be_formatted?
          Yast::UI.ChangeWidget(Id(:format_device), :Value, true)

          @encrypt_widget.enable
          @filesystem_widget.enable
          @partition_id.disable
        else
          Yast::UI.ChangeWidget(Id(:no_format_device), :Value, true)

          # If there is already a filesystem we want to respect, we can't decide
          # on the encryption value
          controller.filesystem ? @encrypt_widget.disable : @encrypt_widget.enable
          @filesystem_widget.disable
          @partition_id.enable
        end
      end

      # @macro seeAbstractWidget
      def handle(event)
        case event["ID"]
        when :format_device
          select_format
        when @filesystem_widget.event_id
          select_format
        when :no_format_device
          select_no_format
        when @partition_id.event_id
          change_partition_id
        end

        nil
      end

      def help
        text = _("<p>First, choose whether the partition should be\n" \
                "formatted and the desired file system type.</p>")

        text +=
          _(
            "<p>If you want to encrypt all data on the\n" \
            "volume, select <b>Encrypt Device</b>. Changing the encryption on an existing\n" \
            "volume will delete all data on it.</p>\n"
          )
        text +=
          _(
            "<p>Then, choose whether the partition should\n" \
            "be mounted and enter the mount point (/, /boot, /home, /var, etc.).</p>"
          )

        text
      end

      def contents
        Frame(
          _("Formatting Options"),
          MarginBox(
            1.45,
            0.5,
            VBox(
              RadioButtonGroup(
                Id(:format),
                VBox(
                  Left(RadioButton(Id(:format_device), Opt(:notify), _("Format device"))),
                  HBox(
                    HSpacing(4),
                    VBox(
                      Left(@filesystem_widget),
                      Left(@format_options)
                    )
                  ),
                  Left(RadioButton(Id(:no_format_device), Opt(:notify), _("Do not format device"))),
                  @partition_id
                )
              ),
              Left(@encrypt_widget)
            )
          )
        )
      end

    private

      attr_reader :controller

      def select_format
        controller.new_filesystem(@filesystem_widget.value)
        refresh
        @parent_widget.refresh_others(self)
      end

      def select_no_format
        controller.dont_format
        refresh
        @parent_widget.refresh_others(self)
      end

      def change_partition_id
        controller.partition_id = @partition_id.value
        refresh
        @parent_widget.refresh_others(self)
      end
    end

    # Mount options for {Y2Storage::BlkDevice}
    class MountOptions < CWM::CustomWidget
      # @param controller [Actions::Controllers::Filesystem]
      # @param parent_widget [#refresh_others] container widget that must be
      #   notified after every relevant update to the controller information
      def initialize(controller, parent_widget)
        textdomain "storage"

        @controller = controller
        @parent_widget = parent_widget

        @mount_point_widget = MountPoint.new(controller)
        @fstab_options_widget = FstabOptionsButton.new(controller)
        @btrfs_subvolumes_widget = BtrfsSubvolumesButton.new(controller)

        self.handle_all_events = true
      end

      def filesystem
        @controller.filesystem
      end

      # @macro seeAbstractWidget
      def init
        refresh
      end

      # Synchronize the widget with the information from the controller
      def refresh
        @mount_point_widget.refresh
        @btrfs_subvolumes_widget.refresh

        if filesystem
          Yast::UI.ChangeWidget(Id(:mount_device), :Enabled, true)

          if filesystem.mountpoint.nil? || filesystem.mountpoint.empty?
            Yast::UI.ChangeWidget(Id(:no_mount_device), :Value, true)
            @mount_point_widget.disable
            @fstab_options_widget.disable
          else
            Yast::UI.ChangeWidget(Id(:mount_device), :Value, true)
            @mount_point_widget.enable
            @fstab_options_widget.enable
          end
        else
          Yast::UI.ChangeWidget(Id(:mount_device), :Enabled, false)

          Yast::UI.ChangeWidget(Id(:no_mount_device), :Value, true)
          @mount_point_widget.disable
          @fstab_options_widget.disable
        end
      end

      def contents
        Frame(
          _("Mounting Options"),
          MarginBox(
            1.45,
            0.5,
            VBox(
              RadioButtonGroup(
                Id(:mount),
                VBox(
                  Left(RadioButton(Id(:mount_device), Opt(:notify), _("Mount device"))),
                  HBox(
                    HSpacing(4),
                    VBox(
                      Left(@mount_point_widget),
                      Left(@fstab_options_widget)
                    )
                  ),
                  Left(RadioButton(Id(:no_mount_device), Opt(:notify), _("Do not mount device")))
                )
              ),
              HBox(Left(@btrfs_subvolumes_widget))
            )
          )
        )
      end

      # @macro seeAbstractWidget
      def handle(event)
        refresh_others = true

        case event["ID"]
        when :mount_device
          mount_device
        when :no_mount_device
          no_mount_device
        when @mount_point_widget.widget_id
          mount_point_change
        else
          refresh_others = false
        end
        @parent_widget.refresh_others(self) if refresh_others

        nil
      end

    private

      def mount_device
        @controller.mount_point = @mount_point_widget.value.to_s
        @fstab_options_widget.enable
        @mount_point_widget.enable
      end

      def no_mount_device
        @controller.mount_point = ""
        @fstab_options_widget.disable
        @mount_point_widget.disable
      end

      def mount_point_change
        mount_point = @mount_point_widget.value.to_s
        @controller.mount_point = mount_point
        if mount_point.nil? || mount_point.empty?
          @fstab_options_widget.disable
        else
          @fstab_options_widget.enable
        end
      end
    end

    # BlkDevice Filesystem selector
    class BlkDeviceFilesystem < CWM::ComboBox
      SUPPORTED_FILESYSTEMS = %i(swap btrfs ext2 ext3 ext4 vfat xfs).freeze

      # Id for the events generated by this widget
      #
      # Useful for other widgets with handle_all_events
      alias_method :event_id, :widget_id

      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
      end

      # @macro seeAbstractWidget
      def opt
        %i(hstretch notify)
      end

      # @macro seeAbstractWidget
      def init
        refresh
      end

      # Synchronize the widget with the information from the controller
      def refresh
        fs_type = @controller.filesystem_type
        self.value = fs_type ? fs_type.to_sym : nil
      end

      def label
        _("Filesystem")
      end

      def items
        Y2Storage::Filesystems::Type.all.select { |fs| supported?(fs) }.map do |fs|
          [fs.to_sym, fs.to_human_string]
        end
      end

    private

      def supported?(fs)
        SUPPORTED_FILESYSTEMS.include?(fs.to_sym)
      end
    end

    # Widget to support the current UI hack in which the snapshots checkbox and
    # the format options button are displayed alternatively based on the
    # filesystem type and other criteria.
    #
    # The behavior is not 100% the same than the old partitioner (which
    # sometimes leaded to unsupported situations), but is equivalent for all the
    # supported scenarios.
    class FormatOptionsArea < CWM::ReplacePoint
      def initialize(controller)
        @controller       = controller
        @options_button   = FormatOptionsButton.new(controller)
        @snapper_checkbox = Snapshots.new(controller)
        super(id: "format_options_area", widget: @options_button)
      end

      alias_method :show, :replace

      # @macro seeAbstractWidget
      def init
        refresh
      end

      # Synchronizes the widget with the information from the controller
      def refresh
        if @controller.snapshots_supported?
          show(@snapper_checkbox)
          @snapper_checkbox.refresh
        else
          show(@options_button)
          @controller.format_options_supported? ? @options_button.enable : @options_button.disable
        end
      end
    end

    # Push Button that launches a dialog to set speficic options for the
    # selected filesystem
    class FormatOptionsButton < CWM::PushButton
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        @controller = controller
      end

      # @macro seeAbstractWidget
      def opt
        %i(hstretch notify)
      end

      def label
        _("Options...")
      end

      # @macro seeAbstractWidget
      def handle
        Yast::Popup.Error("Not yet implemented") # Dialogs::FormatOptions.new(@options).run

        nil
      end
    end

    # Btrfs snapshots selector
    class Snapshots < CWM::CheckBox
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        @controller = controller
      end

      def label
        _("Enable Snapshots")
      end

      # @macro seeAbstractWidget
      def opt
        %i(notify)
      end

      # Synchronizes the widget with the information from the controller
      def refresh
        self.value = @controller.configure_snapper
      end

      # @macro seeAbstractWidget
      def handle(event)
        @controller.configure_snapper = value if event["ID"] == widget_id
        nil
      end
    end

    # MountPoint selector
    class MountPoint < CWM::ComboBox
      SUGGESTED_MOUNT_POINTS = %w(/ /home /var /opt /srv /tmp).freeze

      # Constructor
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        @controller = controller
      end

      # @macro seeAbstractWidget
      def init
        refresh
      end

      # Synchronize the widget with the information from the controller
      def refresh
        self.value = @controller.mount_point
      end

      def label
        _("Mount Point")
      end

      # @macro seeAbstractWidget
      def opt
        %i(editable hstretch notify)
      end

      def items
        SUGGESTED_MOUNT_POINTS.map { |mp| [mp, mp] }
      end

      # The following condintions are checked:
      # - The mount point is not empty
      # - The mount point is unique
      # - The mount point does not shadow a subvolume that cannot be auto deleted
      def validate
        return true if !enabled?

        content_validation && uniqueness_validation && subvolumes_shadowing_validation
      end

    private

      # Validates not empty mount point
      # An error popup is shown when an empty mount point is entered.
      #
      # @return [Boolean] true if mount point is not empty
      def content_validation
        return true unless value.empty?

        Yast::Popup.Error(_("Empty mount point not allowed."))
        false
      end

      # Validates that mount point is unique in the whole system
      # An error popup is shown when the mount point already exists.
      #
      # @see #duplicated_mount_point?
      #
      # @return [Boolean] true if mount point is unique
      def uniqueness_validation
        return true unless duplicated_mount_point?

        Yast::Popup.Error(_("This mount point is already in use. Select a different one."))
        false
      end

      # Validates that the mount point does not shadow a subvolume that cannot be auto deleted
      # An error popup is shown when a subvolume is shadowed by the mount point.
      #
      # @return [Boolean] true if mount point does not shadow a subvolume
      def subvolumes_shadowing_validation
        subvolumes = mounted_devices.select { |d| d.is?(:btrfs_subvolume) && !d.can_be_auto_deleted? }
        subvolumes_mount_points = subvolumes.map(&:mount_point).compact.select { |m| !m.empty? }

        subvolumes_mount_points.each do |mount_point|
          next unless Y2Storage::BtrfsSubvolume.shadowing?(value, mount_point)
          Yast::Popup.Error(
            format(_("The Btrfs subvolume mounted at %s is shadowed."), mount_point)
          )
          return false
        end

        true
      end

      # Checks if the mount point is duplicated
      # @return [Boolean]
      def duplicated_mount_point?
        # The special mount point "swap" can be used for several devices at the
        # same time.
        return false if value == "swap"

        devices = mounted_devices.reject { |d| d.is?(:btrfs_subvolume) }
        mount_points = devices.map(&:mount_point)
        mount_points.include?(value)
      end

      # Returns the devices that are currently mounted in the system
      # It prevents to return the devices associated to the current filesystem.
      #
      # @see #filesystem_devices
      #
      # @return [Array<Y2Storage::Mountable>]
      def mounted_devices
        fs_sids = filesystem_devices.map(&:sid)
        devices = Y2Storage::Mountable.all(device_graph)
        devices = devices.select { |d| !d.mount_point.nil? && !d.mount_point.empty? }
        devices.reject { |d| fs_sids.include?(d.sid) }
      end

      # Returns the devices associated to the current filesystem.
      #
      # @note The devices associated to the filesystem are the filesystem itself and its
      #   subvolumes in case of a btrfs filesystem.
      #
      # @return [Array<Y2Storage::Mountable>]
      def filesystem_devices
        fs = filesystem
        return [] if fs.nil?

        devices = [fs]
        devices += filesystem_subvolumes if fs.is?(:btrfs)
        devices
      end

      # Subvolumes to take into account
      # @return [Array[Y2Storage::BtrfsSubvolume]]
      def filesystem_subvolumes
        filesystem.btrfs_subvolumes.select { |s| !s.top_level? && !s.default_btrfs_subvolume? }
      end

      def device_graph
        DeviceGraphs.instance.current
      end

      def filesystem
        @controller.filesystem
      end
    end

    # The subvolumes button is implemented as a replace point to allow hidden it
    class BtrfsSubvolumesButton < CWM::ReplacePoint
      def initialize(controller)
        @controller = controller
        super(id: "subvolumes_button", widget: current_widget)
      end

      def refresh
        replace(current_widget)
      end

    private

      def filesystem
        @controller.filesystem
      end

      def current_widget
        if filesystem && filesystem.supports_btrfs_subvolumes?
          Button.new(@controller)
        else
          CWM::Empty.new("empty_widget")
        end
      end

      # Button to manage btrfs subvolumes
      class Button < CWM::PushButton
        # @param controller [Actions::Controllers::Filesystem]
        def initialize(controller)
          @controller = controller
        end

        def label
          _("Subvolume Handling")
        end

        def handle
          Dialogs::BtrfsSubvolumes.new(@controller.filesystem).run
          nil
        end
      end
    end

    # Encryption selector
    class EncryptBlkDevice < CWM::CheckBox
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        @controller = controller
      end

      def label
        _("Encrypt Device")
      end

      # @macro seeAbstractWidget
      def opt
        %i(notify)
      end

      # @macro seeAbstractWidget
      def init
        refresh
      end

      # Synchronize the widget with the information from the controller
      def refresh
        self.value = @controller.encrypt
      end

      # @macro seeAbstractWidget
      def handle(event)
        @controller.encrypt = value if event["ID"] == widget_id
        nil
      end
    end

    # Inode Size format option
    class InodeSize < CWM::ComboBox
      SIZES = ["auto", "512", "1024", "2048", "4096"].freeze

      def initialize(options)
        @options = options
      end

      def label
        _("&Inode Size")
      end

      def items
        SIZES.map { |s| [s, s] }
      end
    end

    # Block Size format option
    class BlockSize < CWM::ComboBox
      SIZES = ["auto", "512", "1024", "2048", "4096"].freeze

      def initialize(options)
        @options = options
      end

      def label
        _("Block &Size in Bytes")
      end

      def help
        "<p><b>Block Size:</b>\nSpecify the size of blocks in bytes. " \
          "Valid block size values are 512, 1024, 2048 and 4096 bytes " \
          "per block. If auto is selected, the standard block size of " \
          "4096 is used.</p>\n"
      end

      def items
        SIZES.map { |s| [s, s] }
      end
    end

    # Partition identifier selector or empty widget if changing the partition id
    # is not possible
    class PartitionId < CWM::CustomWidget
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        @controller = controller
        @selector = PartitionIdComboBox.new(controller) if controller.partition_id_supported?
      end

      # @macro seeAbstractWidget
      def contents
        if @selector
          HBox(HSpacing(4), Left(@selector))
        else
          Empty()
        end
      end

      # Synchronize the widget with the information from the controller
      def refresh
        @selector.refresh if @selector
      end

      # @macro seeAbstractWidget
      def enable
        @selector.enable if @selector
      end

      # @macro seeAbstractWidget
      def disable
        @selector.disable if @selector
      end

      # Id for the events generated by this widget
      #
      # Useful for other widgets with handle_all_events
      def event_id
        @selector.widget_id if @selector
      end

      def value
        @selector.value if @selector
      end
    end

    # Partition identifier selector
    class PartitionIdComboBox < CWM::ComboBox
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        @controller = controller
      end

      # @macro seeAbstractWidget
      def opt
        %i(hstretch notify)
      end

      # @macro seeAbstractWidget
      def init
        refresh
      end

      # Synchronize the widget with the information from the controller
      def refresh
        self.value = @controller.partition_id.to_sym
      end

      def label
        _("File system &ID:")
      end

      def items
        Y2Storage::PartitionId.all.map do |part_id|
          [part_id.to_sym, part_id.to_human_string]
        end
      end
    end
  end
end
