require "yast"
require "y2storage"
require "cwm/custom_widget"
require "y2partitioner/refinements/filesystem_type"
require "y2partitioner/format_mount/options"
require "y2partitioner/dialogs/fstab_options"
require "y2partitioner/widgets/fstab_options"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Format options for {Y2Storage::BlkDevice}
    #
    # This widget generates a Frame Term with the format and encrypt options,
    # redrawing the interface in case of filesystem or partition selection
    # change.
    class FormatOptions < CWM::CustomWidget
      using Refinements::FilesystemType

      def initialize(options)
        textdomain "storage"

        @options = options
        @encrypt_widget    = EncryptBlkDevice.new(@options)
        @filesystem_widget = BlkDeviceFilesystem.new(@options)
        @format_options    = FormatOptionsButton.new(@options)
        @partition_id      = PartitionId.new(@options)

        self.handle_all_events = true
      end

      # It disable the format option if the current filesystem is not
      # formattable or the selected partition does not allow format
      def init
        if @options.filesystem_type && !@options.filesystem_type.formattable?
          disable_format
        else
          Yast::UI.ChangeWidget(Id(:no_format_device), :Enabled, true)
          @options.format ? select_format : select_no_format

          @options.partition_id.formattable? ? enable_format : disable_format
        end
      end

      def store
        @options.format = format?
      end

      def handle(event)
        case event["ID"]
        when :format_device
          select_format
        when :no_format_device
          select_no_format
        when @filesystem_widget.widget_id
          return :redraw_filesystem
        when @partition_id.widget_id
          return :redraw_partition_id
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
                  HBox(HSpacing(4), Left(@partition_id))
                )
              ),
              Left(@encrypt_widget)
            )
          )
        )
      end

    private

      def select_format
        @filesystem_widget.enable
        @format_options.enable
        @partition_id.disable
        Yast::UI.ChangeWidget(Id(:format_device), :Value, true)
        @format = true
      end

      def select_no_format
        @filesystem_widget.disable
        @format_options.disable
        @partition_id.enable

        Yast::UI.ChangeWidget(Id(:no_format_device), :Value, true)
        @format = false
      end

      def format?
        Yast::UI::QueryWidget(Id(:format_device), :Value)
      end

      def disable_format
        select_no_format
        Yast::UI.ChangeWidget(Id(:format_device), :Enabled, false)
      end

      def enable_format
        Yast::UI.ChangeWidget(Id(:format_device), :Enabled, true)
      end
    end

    # Mount options for {Y2Storage::BlkDevice}
    class MountOptions < CWM::CustomWidget
      using Refinements::FilesystemType

      def initialize(options)
        textdomain "storage"

        @options = options

        @mount_point_widget = MountPoint.new(@options)
        @fstab_options_widget = FstabOptionsButton.new(@options)

        self.handle_all_events = true
      end

      def reload
        @mount_point_widget.init
      end

      def init
        if !@options.partition_id.formattable? || !@options.filesystem_type.formattable?
          Yast::UI.ChangeWidget(Id(:mount_device), :Enabled, false)
          @options.mount = nil
        end

        if @options.mount
          @fstab_options_widget.enable
          Yast::UI.ChangeWidget(Id(:mount_device), :Value, true)
        else
          @mount_point_widget.disable
          @fstab_options_widget.disable
          Yast::UI.ChangeWidget(Id(:no_mount_device), :Value, true)
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
              )
            )
          )
        )
      end

      def handle(event)
        case event["ID"]
        when :mount_device
          @mount_point_widget.enable
          if @mount_point_widget.value.to_s.empty?
            @fstab_options_widget.disable
          else
            @fstab_options_widget.enable
          end
        when :no_mount_device
          @fstab_options_widget.disable
          @mount_point_widget.disable
        when @mount_point_widget.widget_id
          if @mount_point_widget.value.to_s.empty?
            @fstab_options_widget.disable
          else
            @fstab_options_widget.enable
          end
        end

        nil
      end

      def store
        @options.mount = mount?
        @options.mount_point = @mount_point_widget.value

        nil
      end

    private

      def mount?
        Yast::UI.QueryWidget(Id(:mount_device), :Value)
      end
    end

    # BlkDevice Filesystem selector
    class BlkDeviceFilesystem < CWM::ComboBox
      SUPPORTED_FILESYSTEMS = %i(swap btrfs ext2 ext3 ext4 vfat xfs reiserfs).freeze

      def initialize(options)
        textdomain "storage"

        @options = options
      end

      def opt
        %i(hstretch notify)
      end

      def init
        fs_type = @options.filesystem_type
        self.value = fs_type ? fs_type.to_sym : nil
      end

      def label
        _("Filesystem")
      end

      def items
        return [] unless @options.filesystem_type

        Y2Storage::Filesystems::Type.all.select { |fs| supported?(fs) }.map do |fs|
          [fs.to_sym, fs.to_human_string]
        end
      end

      def store
        @options.filesystem_type = value ? Y2Storage::Filesystems::Type.find(value) : value
      end

    private

      def supported?(fs)
        SUPPORTED_FILESYSTEMS.include?(fs.to_sym)
      end
    end

    # Push Button that launches a dialog to set speficic options for the
    # selected filesystem
    class FormatOptionsButton < CWM::PushButton
      def initialize(options)
        @options = options
      end

      def opt
        %i(hstretch notify)
      end

      def label
        _("Options...")
      end

      def handle
        Yast::Popup.Error("Not yet implemented") # Dialogs::FormatOptions.new(@options).run

        nil
      end
    end

    # MountPoint selector
    # FIXME: Implement validate, verifying if the mount_point is in use.
    class MountPoint < CWM::ComboBox
      SUGGESTED_MOUNT_POINTS = %w(/ /home /var /opt /srv /tmp).freeze

      def initialize(options)
        @options = options
      end

      def init
        self.value = @options.mount_point
      end

      def label
        _("Mount Point")
      end

      def opt
        %i(editable hstretch notify)
      end

      def store
        @options.mount_point = value
      end

      def items
        SUGGESTED_MOUNT_POINTS.map { |mp| [mp, mp] }
      end

      def validate
        true
      end
    end

    # Encryption selector
    class EncryptBlkDevice < CWM::CheckBox
      using Refinements::FilesystemType

      def initialize(options)
        @options = options
      end

      def label
        _("Encrypt Device")
      end

      def init
        if @options.filesystem_type && !@options.filesystem_type.encryptable?
          self.value = false
          disable
        else
          self.value = @options.encrypt
        end
      end

      def store
        @options.encrypt = value
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

    # Partition identifier selector
    class PartitionId < CWM::ComboBox
      def initialize(options)
        @options = options
      end

      def opt
        %i(hstretch notify)
      end

      # FIXME: initialize with the correct value
      def init
        self.value = @options.partition_id.to_sym
      end

      def store
        @options.partition_id = Y2Storage::PartitionId.find(value)
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
