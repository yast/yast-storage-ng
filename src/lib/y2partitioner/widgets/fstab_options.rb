# Copyright (c) [2017-2020] SUSE LLC
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
require "y2partitioner/dialogs/fstab_options"

Yast.import "Popup"

module Y2Partitioner
  # Partitioner widgets
  module Widgets
    include Yast::Logger

    # The fstab options are mostly checkboxes and combo boxes that share some
    # common methods, so this is a mixin for that shared code.
    module FstabCommon
      # @param controller [Y2Partitioner::Actions::Controllers:Filesystem]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
      end

      # @macro seeAbstractWidget
      def init
        init_regexp if self.class.const_defined?("REGEXP")
      end

      # Not all the fstab options are supported by all the filesystems so each
      # widget is able to check if the current filesystem is supported
      # explicitely or checking if the values it is responsible for are
      # supported by the filesystem.
      def supported_by_filesystem?
        return false if filesystem.nil?

        if self.class.const_defined?("SUPPORTED_FILESYSTEMS")
          self.class::SUPPORTED_FILESYSTEMS
            .include?(filesystem.type.to_sym)
        elsif self.class.const_defined?("VALUES")
          self.class::VALUES.all? do |v|
            filesystem.type.supported_fstab_options.include?(v)
          end
        else
          false
        end
      end

      # @param widget [CWM::AbstractWidget]
      # @return [CWM::WidgetTerm]
      def to_ui_term(widget)
        return Empty() unless widget.supported_by_filesystem?

        Left(widget)
      end

      # @param widget [CWM::AbstractWidget]
      # @return [Array<CWM::WidgetTerm>]
      def ui_term_with_vspace(widget)
        return [Empty()] unless widget.supported_by_filesystem?

        [Left(widget), VSpacing(1)]
      end

      # Removes from the MountPoint object the options that not longer apply
      def delete_fstab_option!(option)
        # The options can only be modified using MountPoint#mount_options=
        mount_point.mount_options = mount_point.mount_options.reject { |o| o =~ option }
      end

      # Adds new options to the MountPoint object
      def add_fstab_options(*options)
        # The options can only be modified using MountPoint#mount_options=
        mount_point.mount_options = mount_point.mount_options + options
      end

      alias_method :add_fstab_option, :add_fstab_options

      private

      # Current devicegraph
      #
      # @return [Y2Storage::Devicegraph]
      def working_graph
        DeviceGraphs.instance.current
      end

      # Filesystem currently being edited
      #
      # @return [Y2Storage::Filesystems::Base]
      def filesystem
        @controller.filesystem
      end

      # Check if the underlying filesystem is a btrfs.
      #
      # @return [Boolean]
      def btrfs?
        @controller.btrfs?
      end

      # Mount point of the current filesystem
      #
      # @return [Y2Storage::MountPoint]
      def mount_point
        @controller.mount_point
      end

      # Mount path of the current filesystem
      #
      # @return [String]
      def mount_path
        return nil if filesystem.mount_point.nil?

        filesystem.mount_point.path
      end

      # Common regexp checkbox widgets init.
      def init_regexp
        i = mount_point.mount_options.index { |o| o =~ self.class::REGEXP }

        self.value =
          if i
            mount_point.mount_options[i].gsub(self.class::REGEXP, "")
          else
            self.class::DEFAULT
          end
      end
    end

    # Push button that launch a dialog to set the fstab options
    class FstabOptionsButton < CWM::PushButton
      include FstabCommon

      # @macro seeAbstractWidget
      def label
        _("Fstab Options...")
      end

      # @macro seeAbstractWidget
      def handle
        log.info("fstab_options before dialog: #{mount_point.mount_options}")
        Dialogs::FstabOptions.new(@controller).run
        log.info("fstab_options after dialog: #{mount_point.mount_options}")

        nil
      end
    end

    # FIXME: The help handle does not work without wizard
    # Main widget for set all the available options for a particular filesystem
    class FstabOptions < CWM::CustomWidget
      include FstabCommon

      # Filesystem types that can be configured
      SUPPORTED_FILESYSTEMS = [:btrfs, :ext2, :ext3, :ext4].freeze

      def initialize(controller)
        @controller = controller

        self.handle_all_events = true
      end

      # @macro seeAbstractWidget
      def init
        @contents = nil
        @values = nil
        @regexps = nil
        disable if !supported_by_filesystem?
      end

      # @macro seeAbstractWidget
      def handle(event)
        case event["ID"]
        when :help
          help = []

          widgets.each do |w|
            help << w.help if w.respond_to? "help"
          end

          Yast::Wizard.ShowHelp(help.join("\n"))
        end

        nil
      end

      # @macro seeCustomWidget
      def contents
        @contents ||=
          VBox(
            Left(MountBy.new(@controller)),
            VSpacing(1),
            Left(VolumeLabel.new(@controller, self)),
            VSpacing(1),
            Left(GeneralOptions.new(@controller)),
            Left(FilesystemsOptions.new(@controller)),
            * ui_term_with_vspace(JournalOptions.new(@controller)),
            Left(ArbitraryOptions.new(@controller, self))
          )
      end

      # Return an array of all VALUES of all widgets in this tree.
      # @return [Array<String>]
      def values
        @values ||= widgets.each_with_object([]) do |widget, values|
          next unless widget.class.const_defined?("VALUES")

          values.concat(widget.class::VALUES)
        end.uniq
      end

      # Return an array of all REGEXPs of all widgets in this tree.
      # @return [Array<Regexp>]
      def regexps
        @regexps ||= widgets.each_with_object([]) do |widget, regexps|
          next unless widget.class.const_defined?("REGEXP")

          regexps << widget.class::REGEXP
        end.uniq
      end

      def widgets
        Yast::CWM.widgets_in_contents([self])
      end
    end

    # Input field to set the partition Label
    class VolumeLabel < CWM::InputField
      include FstabCommon

      # Constructor
      #
      # @param controller [Actions::Controllers:Filesystem]
      # @param parent_widget [Widgets::FstabOptions]
      def initialize(controller, parent_widget)
        super(controller)

        @parent_widget = parent_widget
      end

      # @macro seeAbstractWidget
      def label
        _("Volume &Label")
      end

      # @macro seeAbstractWidget
      def store
        filesystem.label = value
      end

      # @macro seeAbstractWidget
      def init
        self.value = filesystem.label
        Yast::UI.ChangeWidget(Id(widget_id), :ValidChars, valid_chars)
        Yast::UI.ChangeWidget(Id(widget_id), :InputMaxLength, input_max_length)
      end

      # Validates uniqueness of the given label. The presence of the label is also
      # checked when the filesystem is set to be mounted by label.
      #
      # @note An error popup message is presented when it is needed.
      #
      # @return [Boolean]
      def validate
        presence_validation && uniqueness_validation
      end

      private

      # @return [Widgets::FstabOptions]
      attr_reader :parent_widget

      # Checks whether a label is given when the filesystem is mounted by label
      #
      # @note An error popup is presented when the filesystem is mounted by label
      #   but a label is not given.
      #
      # @return [Boolean]
      def presence_validation
        return true unless mounted_by_label?
        return true unless value.empty?

        # TRANSLATORS: Error messagge when the label is not given.
        Yast::Popup.Error(_("Provide a volume label to mount by label."))
        focus

        false
      end

      # Checks whether a filesystem already exists with the given label
      #
      # @note An error popup is presented when other filesystem has the given label.
      #
      # @return [Boolean]
      def uniqueness_validation
        return true unless duplicated_label?

        # TRANSLATORS: Error message when the given label is already in use.
        Yast::Popup.Error(_("This volume label is already in use. Select a different one."))
        focus

        false
      end

      # Whether the mount by label option is selected
      #
      # @return [Boolean] true if mount by label is selected; false otherwise.
      def mounted_by_label?
        mount_by_widget.value == :label
      end

      # Whether the given label is duplicated
      #
      # @return [Boolean] true if the label is duplicated; false otherwise.
      def duplicated_label?
        return false if value.empty?

        working_graph.filesystems.any? do |fs|
          next false if fs.sid == filesystem.sid
          next false unless fs.respond_to?(:label) # NFS doesn't support labels

          fs.label == value
        end
      end

      # Widget to select the mount by option
      #
      # @return [MountBy]
      def mount_by_widget
        parent_widget.widgets.find { |w| w.is_a?(Y2Partitioner::Widgets::MountBy) }
      end

      # Sets the focus into this widget
      def focus
        Yast::UI.SetFocus(Id(widget_id))
      end

      # Return the valid characters for this input field
      #
      # @return [String]
      def valid_chars
        filesystem.type.label_valid_chars
      end

      # Return the maximum length of the input (the number of characters) for
      # this input field
      #
      # @return [Integer]
      def input_max_length
        filesystem.max_labelsize
      end
    end

    # A combobox to select the type of identifier to be used for mount
    # the specific device (UUID, Label, Path...)
    class MountBy < CWM::ComboBox
      include FstabCommon

      # @macro seeAbstractWidget
      def label
        _("Mount in /etc/fstab By")
      end

      # @macro seeAbstractWidget
      def init
        select_default_mount_by
      end

      # @macro seeAbstractWidget
      def store
        mount_point.mount_by = selected_mount_by
      end

      # @macro seeCustomWidget
      def items
        # CWM does not support symbols for entries in ComboBoxes
        # contrary to libyui. Otherwise a few conversations between
        # string and symbol below could be avoided.

        suitable = mount_point.suitable_mount_bys(label: true, encryption:
          @controller.encrypt).map { |mount_by| mount_by.to_sym.to_s }

        [
          ["device", _("Device Name")],
          ["id", _("Device ID")],
          ["path", _("Device Path")],
          ["uuid", _("UUID")],
          ["label", _("Volume Label")]
        ].select { |item| suitable.include? item[0] }
      end

      private

      def selected_mount_by
        Y2Storage::Filesystems::MountByType.find(value.to_sym)
      end

      def select_default_mount_by
        self.value = mount_point.mount_by.to_s
      end
    end

    # A group of options that are general for many filesystem types.
    class GeneralOptions < CWM::CustomWidget
      include FstabCommon

      # @macro seeCustomWidget
      def contents
        return Empty() unless widgets.any?(&:supported_by_filesystem?)

        VBox(* widgets.map { |w| to_ui_term(w) }, VSpacing(1))
      end

      def widgets
        [
          ReadOnly.new(@controller),
          MountUser.new(@controller),
          Noauto.new(@controller),
          Quota.new(@controller)
        ]
      end
    end

    # Generic checkbox for fstab options
    # VALUES must be a pair: ["fire", "water"] means "fire" is checked and "water" unchecked
    class FstabCheckBox < CWM::CheckBox
      include FstabCommon

      # @macro seeAbstractWidget
      def init
        self.value = mount_point.mount_options.include?(checked_value)
      end

      # @macro seeAbstractWidget
      def store
        delete_fstab_option!(Regexp.union(options))
        add_fstab_option(checked_value) if value
      end

      private

      # Possible values
      def options
        self.class::VALUES
      end

      def checked_value
        self.class::VALUES[0]
      end
    end

    # CheckBox to disable the automount option when starting up
    class Noauto < FstabCheckBox
      # Possible values of the widget
      VALUES = ["noauto", "auto"].freeze

      # @macro seeAbstractWidget
      def label
        _("Do Not Mount at System &Start-up")
      end
    end

    # CheckBox to enable the read only option ("ro")
    class ReadOnly < FstabCheckBox
      include FstabCommon

      # Possible values of the widget
      VALUES = ["ro", "rw"].freeze

      # @macro seeAbstractWidget
      def label
        _("Mount &Read-Only")
      end

      # @macro seeAbstractWidget
      def help
        _("<p><b>Mount Read-Only:</b>\n" \
        "Writing to the file system is not possible. Default is false. During installation\n" \
        "the file system is always mounted read-write.</p>")
      end
    end

    # CheckBox to enable the user option which means allow to mount the
    # filesystem by an ordinary user
    class MountUser < FstabCheckBox
      # Possible values of the widget
      VALUES = ["user", "nouser"].freeze

      # @macro seeAbstractWidget
      def label
        _("Mountable by User")
      end

      # @macro seeAbstractWidget
      def help
        _("<p><b>Mountable by User:</b>\nThe file system may be " \
        "mounted by an ordinary user. Default is false.</p>\n")
      end
    end

    # CheckBox to enable the use of user quotas
    class Quota < CWM::CheckBox
      include FstabCommon

      # Possible values of the widget
      VALUES = ["grpquota", "usrquota"].freeze

      # @macro seeAbstractWidget
      def label
        _("Enable &Quota Support")
      end

      # @macro seeAbstractWidget
      def help
        _("<p><b>Enable Quota Support:</b>\n" \
          "The file system is mounted with user quotas enabled.\n" \
          "Default is false.</p>")
      end

      # @macro seeAbstractWidget
      def init
        self.value = mount_point.mount_options.any? { |o| VALUES.include?(o) }
      end

      # @macro seeAbstractWidget
      def store
        delete_fstab_option!(Regexp.union(VALUES))
        add_fstab_options("usrquota", "grpquota") if value
      end
    end

    # Generic ComboBox for fstab options.
    #
    # This uses some constants that each derived class should define:
    #
    # REGEXP [Regex] The regular expression describing the fstab option.
    # If it ends with "=", the value will be appended to it.
    #
    # ITEMS [Array<String>] The items to choose from.
    # The first one is used as the default (initial) value.
    #
    class FstabComboBox < CWM::ComboBox
      include FstabCommon

      # Set the combo box value to the current value matching REGEXP.
      def init
        i = mount_point.mount_options.index { |o| o =~ self.class::REGEXP }
        self.value = i ? mount_point.mount_options[i].gsub(self.class::REGEXP, "") : default_value
      end

      # Convert REGEXP to the option string. This is a very basic
      # implementation that just removes a "^" if the regexp contains it.
      # For anything more sophisticated, reimplement this.
      #
      # @return [String]
      def option_str
        self.class::REGEXP.source.delete("^")
      end

      # Overriding FstabCommon::supported_by_filesystem? to make use of the
      # REGEXP and to avoid having to duplicate it in VALUES
      #
      # @return [Boolean]
      def supported_by_filesystem?
        return false if filesystem.nil?
        return false unless supported_by_mount_path?

        filesystem.type.supported_fstab_options.any? { |opt| opt =~ self.class::REGEXP }
      end

      # Check if this mount option is supported by the current mount path.
      # For /boot/* or the root filesystem some options might not be supported.
      #
      # @return [Boolean]
      def supported_by_mount_path?
        true
      end

      # The default value for the option.
      #
      # @return [String]
      def default_value
        items.first.first
      end

      # Store the current value in the fstab_options.
      # If the value is nil or empty, it will only remove the old value.
      #
      # If option_str (i.e. normally REGEXP) ends with "=", the value is
      # appended to it, otherwise only the value is used.
      # "codepage=" -> "codepage=value"
      # "foo" -> "value"
      def store
        delete_fstab_option!(self.class::REGEXP)
        return if value.nil? || value.empty?

        opt = option_str
        if opt.end_with?("=")
          opt += value
        else
          opt = value
        end
        add_fstab_option(opt)
      end

      # Convert ITEMS to the format expected by the underlying
      # CWM::ComboBox.
      def items
        self.class::ITEMS.map { |val| [val, val] }
      end

      # Widget options
      def opt
        [:editable, :hstretch]
      end
    end

    # ComboBox to specify the journal mode to use by the filesystem
    class JournalOptions < FstabComboBox
      # Format of the option
      REGEXP = /^data=/

      # @macro seeAbstractWidget
      def label
        _("Data &Journaling Mode")
      end

      def default_value
        "ordered"
      end

      def items
        [
          ["journal", _("journal")],
          ["ordered", _("ordered")],
          ["writeback", _("writeback")]
        ]
      end

      def supported_by_mount_path?
        # journal options tend to break remounting root rw (bsc#1077859).
        # See also root_fstab_options() in lib/y2storage/filesystems/type.rb
        mount_path != "/"
      end

      # @macro seeAbstractWidget
      def help
        _("<p><b>Data Journaling Mode:</b>\n" \
        "Specifies the journaling mode for file data.\n" \
        "<tt>journal</tt> -- All data is committed to the journal prior to being\n" \
        "written into the main file system. Highest performance impact.<br>\n" \
        "<tt>ordered</tt> -- All data is forced directly out to the main file system\n" \
        "prior to its metadata being committed to the journal. Medium performance impact.<br>\n" \
        "<tt>writeback</tt> -- Data ordering is not preserved. No performance impact.</p>\n")
      end
    end

    # An input field that allows to set other options that are not handled by
    # specific widgets.
    #
    class ArbitraryOptions < CWM::InputField
      include FstabCommon

      def initialize(controller, parent_widget)
        textdomain "storage"
        @controller = controller
        @parent_widget = parent_widget
        @other_values = nil
        @other_regexps = nil
      end

      # @macro seeCustomWidget
      def opt
        [:hstretch]
      end

      # @macro seeAbstractWidget
      def label
        _("Arbitrary Option &Value")
      end

      # @macro seeAbstractWidget
      def init
        self.value = unhandled_options(mount_point.mount_options).join(",")
      end

      # @macro seeAbstractWidget
      def store
        keep_only_options_handled_in_other_widgets
        return unless value

        options = clean_whitespace(value).split(",")
        # Intentionally NOT filtering out only unhandled options: When the user
        # adds anything here that also has a corresponding checkbox or combo
        # box in this same dialog, the value here will win, and when entering
        # this dialog again the dedicated widget will take the value from
        # there, and it will be filtered out in this arbitrary options widget.
        #
        # So, when a user insists in adding "noauto,user" here, it is applied
        # correctly, but when entering the dialog again, the checkboxes pick up
        # those values and they won't show up in this field anymore.
        add_fstab_options(*options)
      end

      # @macro seeAbstractWidget
      def help
        _("<p><b>Arbitrary Option Value:</b> " \
          "Enter any other mount options here, separated with commas. " \
          "Notice that this does not do any checking, so be careful " \
          "what you enter here!</p>")
      end

      private

      # Clean whitespace. We need to preserve whitespace that might possibly be
      # intentional within a mount option, but we want graceful error handling
      # when a user put additional blanks between them, e.g. "foo, bar" or
      # "foo , bar".
      def clean_whitespace(str)
        str.gsub(/\s*,\s*/, ",")
      end

      def keep_only_options_handled_in_other_widgets
        mount_point.mount_options = mount_point.mount_options.select do |opt|
          handled_in_other_widget?(opt)
        end
      end

      def unhandled_options(options)
        options.reject do |opt|
          handled_in_other_widget?(opt)
        end
      end

      def handled_in_other_widget?(opt)
        return true if other_values.include?(opt)

        other_regexps.any? { |r| opt =~ r }
      end

      # Return all values that are handled by other widgets in this widget tree.
      # @return [Array<String>]
      def other_values
        return [] unless @parent_widget&.respond_to?(:values)

        @other_values ||= @parent_widget.values
      end

      # Return all regexps that are handled by other widgets in this widget tree.
      # @return [Array<Regexp>]
      def other_regexps
        return [] unless @parent_widget&.respond_to?(:regexps)

        @other_regexps ||= @parent_widget.regexps
      end
    end

    # Some options that are mainly specific for one filesystem
    class FilesystemsOptions < CWM::CustomWidget
      include FstabCommon

      # @macro seeCustomWidget
      def contents
        return Empty() unless widgets.any?(&:supported_by_filesystem?)

        VBox(* widgets.map { |w| to_ui_term(w) }, VSpacing(1))
      end

      def widgets
        [
          SwapPriority.new(@controller),
          IOCharset.new(@controller),
          Codepage.new(@controller)
        ]
      end
    end

    # Swap priority
    class SwapPriority < CWM::InputField
      include FstabCommon

      # Possible values of the widget
      VALUES = ["pri="].freeze
      # Format of the option
      REGEXP  = /^pri=/
      # Default value of the widget
      DEFAULT = "".freeze

      # @macro seeAbstractWidget
      def label
        _("Swap &Priority")
      end

      # @macro seeAbstractWidget
      def store
        delete_fstab_option!(REGEXP)
        add_fstab_option("pri=#{value}") if value && !value.empty?
      end

      # @macro seeAbstractWidget
      def help
        _("<p><b>Swap Priority:</b>\nEnter the swap priority. " \
        "Higher numbers mean higher priority.</p>\n")
      end
    end

    # VFAT IOCharset
    class IOCharset < FstabComboBox
      # Format of the option
      REGEXP = /^iocharset=/
      # Possible values
      ITEMS = [
        "", "iso8859-1", "iso8859-15", "iso8859-2", "iso8859-5", "iso8859-7",
        "iso8859-9", "utf8", "koi8-r", "euc-jp", "sjis", "gb2312", "big5",
        "euc-kr"
      ].freeze

      # @macro seeAbstractWidget
      def store
        delete_fstab_option!(/^utf8=.*/)
        super
      end

      def default_value
        iocharset = filesystem.type.iocharset
        ITEMS.include?(iocharset) ? iocharset : ITEMS.first
      end

      def supported_by_mount_path?
        return false if mount_path.nil?

        # "iocharset=utf8" breaks VFAT case insensitivity (bsc#1080731).
        # See also boot_fstab_options() in lib/y2storage/filesystems/type.rb
        mount_path != "/boot" && !mount_path.start_with?("/boot/")
      end

      # @macro seeAbstractWidget
      def label
        _("Char&set for File Names")
      end

      # @macro seeAbstractWidget
      def help
        _("<p><b>Charset for File Names:</b>\nSet the charset used for display " \
        "of file names in Windows partitions.</p>\n")
      end
    end

    # VFAT Codepage
    class Codepage < FstabComboBox
      # Format of the option
      REGEXP = /^codepage=/
      # Possible values
      ITEMS = ["", "437", "852", "932", "936", "949", "950"].freeze

      def default_value
        cp = filesystem.type.codepage
        ITEMS.include?(cp) ? cp : ITEMS.first
      end

      # @macro seeAbstractWidget
      def label
        _("Code&page for Short FAT Names")
      end

      # @macro seeAbstractWidget
      def help
        _("<p><b>Codepage for Short FAT Names:</b>\nThis codepage is used for " \
        "converting to shortname characters on FAT file systems.</p>\n")
      end
    end
  end
end
