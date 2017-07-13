require "yast"
require "cwm"
require "y2storage"

module Y2Partitioner
  module Widgets
    # The fstab options are mostly checkboxes and combo boxes that share some
    # commong methods, so this is a mixin for that share code.
    module FstabCommon
      def initialize(options)
        textdomain "storage"

        @options = options
      end

      def init
        init_regexp if self.class.const_defined?("REGEXP")
      end

      # No all the fstab options are supported by all the filesystem so each
      # widget are able to check if the current filesystem is supported
      # explicitely or checking if the values it is responsable of are
      # supported by the filesystem.
      def supported_by_filesystem?
        return false if !@options.filesystem_type

        if self.class.const_defined?("SUPPORTED_FILESYSTEMS")
          self.class::SUPPORTED_FILESYSTEMS
            .include?(@options.filesystem_type.to_sym)
        else
          self.class::VALUES.all? do |v|
            @options.filesystem_type.supported_fstab_options.include?(v)
          end
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

      def delete_from_fstab!(option)
        @options.fstab_options.delete_if { |o| o =~ option }
      end

    private

      # Common regexp checkbox widgets init.
      def init_regexp
        i = @options.fstab_options.index { |o| o =~ self.class::REGEXP }

        self.value =
          if i
            @options.fstab_options[i].gsub(self.class::REGEXP, "")
          else
            self.class::DEFAULT
          end
      end
    end

    # Push button that launch a dialog for set the fstab options
    class FstabOptionsButton < CWM::PushButton
      include FstabCommon

      def label
        _("Fstab options...")
      end

      def handle
        Dialogs::FstabOptions.new(@options).run

        nil
      end
    end

    # FIXME: The help handle does not work without wizard
    # Main widget for set all the available options for a particular filesystem
    class FstabOptions < CWM::CustomWidget
      include FstabCommon

      SUPPORTED_FILESYSTEMS = %i(btrfs ext2 ext3 ext4 reiserfs).freeze

      def initialize(options)
        @options = options

        self.handle_all_events = true
      end

      def init
        disable if !supported_by_filesystem?
      end

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

      def contents
        VBox(
          Left(MountBy.new(@options)),
          VSpacing(1),
          Left(VolumeLabel.new(@options)),
          VSpacing(1),
          Left(GeneralOptions.new(@options)),
          Left(FilesystemsOptions.new(@options)),
          * ui_term_with_vspace(JournalOptions.new(@options)),
          * ui_term_with_vspace(AclOptions.new(@options)),
          Left(ArbitraryOptions.new(@options))
        )
      end

    private

      def widgets
        Yast::CWM.widgets_in_contents([self])
      end
    end

    # Input field to set the partition Label
    class VolumeLabel < CWM::InputField
      include FstabCommon

      def label
        _("Volume &Label")
      end

      def store
        @options.label = value
      end

      def init
        self.value = @options.label
      end
    end

    # Group of radio buttons to select the type of identifier to be used for
    # mouth the specific device (UUID, Label, Path...)
    class MountBy < CWM::CustomWidget
      include FstabCommon

      def label
        _("Mount in /etc/fstab by")
      end

      def store
        @options.mount_by = selected_mount_by
      end

      def init
        value = @options.mount_by ? @options.mount_by.to_sym : :uuid
        Yast::UI.ChangeWidget(Id(:mt_group), :Value, value)
      end

      def contents
        RadioButtonGroup(
          Id(:mt_group),
          VBox(
            Left(Label(label)),
            HBox(
              VBox(
                Left(RadioButton(Id(:device), _("&Device Name"))),
                Left(RadioButton(Id(:label), _("Volume &Label"))),
                Left(RadioButton(Id(:uuid), _("&UUID")))
              ),
              Top(
                VBox(
                  Left(RadioButton(Id(:id), _("Device &ID"))),
                  Left(RadioButton(Id(:path), _("Device &Path")))
                )
              )
            )
          )
        )
      end

      def selected_mount_by
        Y2Storage::Filesystems::MountByType.all.detect do |fs|
          fs.to_sym == value
        end
      end

      def value
        Yast::UI.QueryWidget(Id(:mt_group), :Value)
      end
    end

    # A group of options that are general for many filesystem types.
    class GeneralOptions < CWM::CustomWidget
      include FstabCommon

      def contents
        return Empty() unless widgets.any?(&:supported_by_filesystem?)

        VBox(* widgets.map { |w| to_ui_term(w) }, VSpacing(1))
      end

      def widgets
        [
          ReadOnly.new(@options),
          Noatime.new(@options),
          MountUser.new(@options),
          Noauto.new(@options),
          Quota.new(@options)
        ]
      end
    end

    # Generic checkbox for fstab options
    # VALUES must be a pair: ["fire", "water"] means "fire" is checked and "water" unchecked
    class FstabCheckBox < CWM::CheckBox
      include FstabCommon

      # FIXME: It is common to almost all regexp widgets not only for checkboxes
      def init
        self.value = @options.fstab_options.include?(checked_value)
      end

      # FIXME: It is common to almost all regexp widgets not only for checkboxes
      def store
        delete_from_fstab!(Regexp.union(options))

        @options.fstab_options << checked_value if value
      end

    private

      def options
        self.class::VALUES
      end

      def checked_value
        self.class::VALUES[0]
      end
    end

    # CheckBox to disable the automount option when starting up
    class Noauto < FstabCheckBox
      VALUES = ["noauto", "auto"].freeze

      def label
        _("Do Not Mount at System &Start-up")
      end
    end

    # CheckBox to enable the read only option ("ro")
    class ReadOnly < FstabCheckBox
      include FstabCommon
      VALUES = ["ro", "rw"].freeze

      def label
        _("Mount &Read-Only")
      end

      def help
        _("<p><b>Mount Read-Only:</b>\n" \
        "Writing to the file system is not possible. Default is false. During installation\n" \
        "the file system is always mounted read-write.</p>")
      end
    end

    # CheckBox to enable the noatime option
    class Noatime < FstabCheckBox
      VALUES = ["noatime", "atime"].freeze

      def label
        _("No &Access Time")
      end

      def help
        _("<p><b>No Access Time:</b>\nAccess times are not " \
        "updated when a file is read. Default is false.</p>\n")
      end
    end

    # CheckBox to enable the user option which means allow to mount the
    # filesystem by an ordinary user
    class MountUser < FstabCheckBox
      VALUES = ["user", "nouser"].freeze

      def label
        _("Mountable by user")
      end

      def help
        _("<p><b>Mountable by User:</b>\nThe file system may be " \
        "mounted by an ordinary user. Default is false.</p>\n")
      end
    end

    # CheckBox to enable the use of user quotas
    class Quota < CWM::CheckBox
      include FstabCommon
      VALUES = ["grpquota", "usrquota"].freeze

      def label
        _("Enable &Quota Support")
      end

      def help
        _("<p><b>Enable Quota Support:</b>\n" \
        "The file system is mounted with user quotas enabled.\n" \
        "Default is false.</p>\n")
      end

      def init
        self.value = @options.fstab_options.any? { |o| VALUES.include?(o) }
      end

      def store
        delete_from_fstab!(Regexp.union(VALUES))

        @options.fstab_options << "usrquota" << "grpquota" if value
      end
    end

    # ComboBox to specify the journal mode to use by the filesystem
    class JournalOptions < CWM::ComboBox
      include FstabCommon

      REGEXP = /^data=/
      VALUES = ["data="].freeze
      DEFAULT = "journal".freeze

      def label
        _("Data &Journaling Mode")
      end

      def store
        delete_from_fstab!(REGEXP)

        @options.fstab_options << "data=#{value}"
      end

      def items
        [
          ["journal", _("journal")],
          ["ordered", _("ordered")],
          ["writeback", _("writeback")]
        ]
      end

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

    # Custom widget that allows to enable ACL and the use of extended
    # attributes
    #
    # TODO: FIXME: Pending implementation, currently it is only draw
    class AclOptions < CWM::CustomWidget
      include FstabCommon

      VALUES = ["acl", "eua"].freeze

      def contents
        VBox(
          Left(CheckBox(Id("opt_acl"), Opt(:disabled), _("&Access Control Lists (ACL)"), false)),
          Left(CheckBox(Id("opt_eua"), Opt(:disabled), _("&Extended User Attributes"), false))
        )
      end
    end

    # A input field that allows to set other options that are not handled by
    # specific widgets
    #
    # TODO: FIXME: Pending implementation, currently it is only draw, all the options
    # that it is responsable of should be defined, removing them if not set or
    # supported by the current filesystem.
    class ArbitraryOptions < CWM::InputField
      def initialize(options)
        @options = options
      end

      def opt
        %i(hstretch disabled)
      end

      def label
        _("Arbitrary Option &Value")
      end
    end

    # Some options that are mainly specific for one filesystem
    class FilesystemsOptions < CWM::CustomWidget
      include FstabCommon

      def contents
        return Empty() unless widgets.any?(&:supported_by_filesystem?)

        VBox(* widgets.map { |w| to_ui_term(w) }, VSpacing(1))
      end

      def widgets
        [
          SwapPriority.new(@options),
          IOCharset.new(@options),
          Codepage.new(@options)
        ]
      end
    end

    # Swap priority
    class SwapPriority < CWM::InputField
      include FstabCommon

      VALUES = ["pri="].freeze
      REGEXP  = /^pri=/
      DEFAULT = "42".freeze

      def label
        _("Swap &Priority")
      end

      def store
        delete_from_fstab!(REGEXP)

        @options.fstab_options << "pri=#{value}"
      end

      def help
        _("<p><b>Swap Priority:</b>\nEnter the swap priority. " \
        "Higher numbers mean higher priority.</p>\n")
      end
    end

    # VFAT IOCharset
    class IOCharset < CWM::ComboBox
      include FstabCommon

      SUPPORTED_FILESYSTEMS = ["vfat"].freeze
      REGEXP = /^iocharset=/
      DEFAULT = "".freeze
      AVAILABLE_VALUES = [
        "", "iso8859-1", "iso8859-15", "iso8859-2", "iso8859-5", "iso8859-7",
        "iso8859-9", "utf8", "koi8-r", "euc-jp", "sjis", "gb2312", "big5",
        "euc-kr"
      ].freeze

      def init
        i = @options.fstab_options.index { |o| o =~ REGEXP }

        self.value = i ? @options.fstab_options[i].gsub(REGEXP, "") : DEFAULT
      end

      def store
        delete_from_fstab!(/^iocharset=/)

        @options.fstab_options << "iocharset=#{value}"
      end

      def label
        _("Char&set for file names")
      end

      def help
        _("<p><b>Charset for File Names:</b>\nSet the charset used for display " \
        "of file names in Windows partitions.</p>\n")
      end

      def opt
        %i(editable hstretch)
      end

      def items
        AVAILABLE_VALUES.map do |ch|
          [ch, ch]
        end
      end
    end

    # VFAT Codepage
    class Codepage < CWM::ComboBox
      include FstabCommon

      CODEPAGES = ["", "437", "852", "932", "936", "949", "950"].freeze
      REGEXP = /^codepage=/
      VALUES = ["codepage="].freeze
      DEFAULT = "".freeze

      def store
        @options.fstab_options.delete_if { |o| o =~ REGEXP }

        @options.fstab_options << "codepage=#{value}" if value && !value.empty?
      end

      def label
        _("Code&page for short FAT names")
      end

      def help
        _("<p><b>Codepage for Short FAT Names:</b>\nThis codepage is used for " \
        "converting to shortname characters on FAT file systems.</p>\n")
      end

      def opt
        %i(editable hstretch)
      end

      def items
        CODEPAGES.map { |ch| [ch, ch] }
      end
    end
  end
end
