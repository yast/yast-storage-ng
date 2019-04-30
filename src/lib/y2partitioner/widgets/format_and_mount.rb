# encoding: utf-8

# Copyright (c) [2017-2019] SUSE LLC
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
require "cwm"
require "y2storage"
require "y2storage/mountable"
require "y2storage/btrfs_subvolume"
require "y2partitioner/filesystems"
require "y2partitioner/widgets/fstab_options"
require "y2partitioner/dialogs/btrfs_subvolumes"

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
        else
          Yast::UI.ChangeWidget(Id(:no_format_device), :Value, true)

          # If there is already a filesystem we want to respect, we can't decide
          # on the encryption value
          controller.filesystem ? @encrypt_widget.disable : @encrypt_widget.enable
          @filesystem_widget.disable
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
          VSpacing(1),
          Left(@encrypt_widget)
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

          if filesystem.mount_point.nil?
            Yast::UI.ChangeWidget(Id(:dont_mount_device), :Value, true)
            @mount_point_widget.disable
            @fstab_options_widget.disable
          else
            Yast::UI.ChangeWidget(Id(:mount_device), :Value, true)
            @mount_point_widget.enable
            @fstab_options_widget.enable
          end
        else
          Yast::UI.ChangeWidget(Id(:mount_device), :Enabled, false)

          Yast::UI.ChangeWidget(Id(:dont_mount_device), :Value, true)
          @mount_point_widget.disable
          @fstab_options_widget.disable
        end
      end

      def contents
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
              Left(RadioButton(Id(:dont_mount_device), Opt(:notify), _("Do not mount device")))
            )
          ),
          VSpacing(1),
          Left(@btrfs_subvolumes_widget)
        )
      end

      # @macro seeAbstractWidget
      def handle(event)
        refresh_others = true

        case event["ID"]
        when :mount_device
          mount_device
        when :dont_mount_device
          dont_mount_device
        when @mount_point_widget.widget_id
          mount_point_change
        else
          refresh_others = false
        end
        @parent_widget.refresh_others(self) if refresh_others

        nil
      end

      def validate
        validate_system_mount_points && validate_mount_by_label
      end

    private

      # It is necessary to prevent an empty filesystem label when the option mount_by is set
      # to label by default. The label value is validated when the user gives one value
      # (by editing the fstab options), but the user could mount a device without entering
      # in that dialog for the mount options.
      #
      # Here only the presence of a label is checked. The correctness of the label is checked
      # when the label is entered (see {Dialogs::FstabOptions}).
      #
      # @return [Boolean] true if the label is not required or it is required and given; false
      #   otherwise.
      def validate_mount_by_label
        return true if !formatted? || !mounted? || !mounted_by_label? || !empty_label?

        # TRANSLATORS: Error message when a device should be mounted by label but no label
        # is given.
        Yast::Popup.Error(_("Provide a volume label to mount by label."))
        false
      end

      # Check if a system mount point is reused without formatting the
      # partition during installation and warn the user if it is.
      #
      # @return [Boolean] true if okay, false if not
      def validate_system_mount_points
        return true unless Yast::Mode.installation
        return true if to_be_formatted?
        return true unless mounted?
        return true unless ["/", "/usr", "/boot"].include?(mount_path)
        warn_unformatted_system_mount_points
      end

      # Post a warning about reusing unformatted system mount points.
      #
      # @return [Boolean] true if the user wants to continue
      def warn_unformatted_system_mount_points
        log.info("warn_unformatted_system_mount_points")
        # Translators: popup text
        message = _(
          "\n" \
          "You chose to install onto an existing partition that will not be\n" \
          "formatted. YaST cannot guarantee your installation will succeed,\n" \
          "particularly in any of the following cases:\n"
        ) +
          # continued popup text
          _(
            "- if this is an existing Btrfs partition\n" \
            "- if this partition already contains a Linux distribution that will be\n" \
            "overwritten\n" \
            "- if this partition does not yet contain a file system\n"
          ) +
          # continued popup text
          _(
            "If in doubt, better go back and mark this partition for\n" \
            "formatting, especially if it is assigned to one of the standard mount points\n" \
            "like /, /boot, /opt or /var.\n"
          ) +
          # continued popup text
          _(
            "If you decide to format the partition, all data on it will be lost.\n" \
            "\n" \
            "Really skip formatting the partition?\n"
          )
        Yast::Popup.YesNo(message)
      end

      def mount_device
        @mount_point_widget.enable
        mount_point_change
      end

      def dont_mount_device
        @controller.remove_mount_point
        @fstab_options_widget.disable
        @mount_point_widget.disable
      end

      def mount_point_change
        if mount_path.empty?
          @controller.remove_mount_point
          @fstab_options_widget.disable
        else
          @controller.create_or_update_mount_point(mount_path)
          @fstab_options_widget.enable
        end
      end

      # Value given for the mount point
      #
      # @return [String]
      def mount_path
        @mount_point_widget.value.to_s
      end

      # Whether the device has a filesystem
      #
      # @return [Boolean] true if it has a filesystem; false otherwise.
      def formatted?
        !@controller.filesystem.nil?
      end

      # Whether the device will be formatted
      #
      # @return [Boolean] true if will be formatted; false otherwise
      def to_be_formatted?
        @controller.to_be_formatted?
      end

      # Whether the device has a mount point
      #
      # @return [Boolean] true if it has a mount point; false otherwise.
      def mounted?
        !@controller.mount_point.nil?
      end

      # Whether the device is set to be mounted by label
      #
      # @return [Boolean] true if it is set to mount by label; false otherwise.
      def mounted_by_label?
        mounted? && @controller.mount_point.mount_by.is?(:label)
      end

      # Whether the filesystem has a label
      #
      # @return [Boolean] true if it has a label; false otherwise.
      def empty_label?
        !formatted? || @controller.filesystem.label.empty?
      end
    end

    # BlkDevice Filesystem selector
    class BlkDeviceFilesystem < CWM::ComboBox
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
        Y2Partitioner::Filesystems.all.map { |f| [f.to_sym, f.to_human_string] }
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
        textdomain "storage"
        @controller = controller
      end

      def filesystem
        @controller.filesystem
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
        log.info(
          "format options before: [#{filesystem.type}] " \
          "mkfs='#{filesystem.mkfs_options}', tune='#{filesystem.tune_options}'"
        )
        Dialogs::MkfsOptions.new(@controller).run
        log.info(
          "format options after: [#{filesystem.type}] " \
          "mkfs='#{filesystem.mkfs_options}', tune='#{filesystem.tune_options}'"
        )
        nil
      end
    end

    # Btrfs snapshots selector
    class Snapshots < CWM::CheckBox
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        textdomain "storage"
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
      # Constructor
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        textdomain "storage"
        @controller = controller
      end

      # @macro seeAbstractWidget
      def init
        refresh
      end

      # Synchronize the widget with the information from the controller
      def refresh
        self.value = @controller.mount_path
      end

      def label
        _("Mount Point")
      end

      # @macro seeAbstractWidget
      def opt
        %i(editable hstretch notify)
      end

      def items
        controller.mount_paths.map { |mp| [mp, mp] }
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

      # @return [Actions::Controllers::Filesystem]
      attr_reader :controller

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
        controller.subvolumes_mount_paths.each do |mount_path|
          next unless Y2Storage::BtrfsSubvolume.shadowing?(value, mount_path)
          Yast::Popup.Error(
            format(_("The Btrfs subvolume mounted at %s is shadowed."), mount_path)
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

        controller.mounted_paths.include?(value)
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
    end

    # Button to manage btrfs subvolumes
    class Button < CWM::PushButton
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        textdomain "storage"
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

    # Encryption selector
    class EncryptBlkDevice < CWM::CheckBox
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        textdomain "storage"
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

      # validates if it can be encrypted
      def validate
        return true unless value

        # FIXME: have generic check when new partition is created if it is valid
        # like e.g. if fs fits to partition, and others
        # size number is from bsc1065071#c5
        return true if @controller.blk_device.size > ::Y2Storage::DiskSize.MiB(2)

        ::Yast::Popup.Error(_("Only devices bigger than 2 MiB can be encrypted."))
        false
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
        textdomain "storage"
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
        textdomain "storage"
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
        textdomain "storage"
        @controller = controller
        @selector = PartitionIdComboBox.new(controller) if controller.partition_id_supported?
      end

      # @macro seeAbstractWidget
      def contents
        if @selector
          VBox(VSpacing(1), Left(@selector))
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
        self.value = @controller.partition_id.to_sym
      end

      def label
        _("Partition &ID:")
      end

      def items
        blk_dev = @controller.blk_device
        if blk_dev.is?(:partition)
          blk_dev.partition_table.supported_partition_ids.sort.map do |part_id|
            [part_id.to_sym, part_id.to_human_string]
          end
        else
          []
        end
      end
    end
  end
end
