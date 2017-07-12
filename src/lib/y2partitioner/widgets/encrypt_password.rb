require "yast"
require "cwm"
require "y2storage"

module Y2Partitioner
  module Widgets
    # Encrypted {Y2Storage::BlkDevice} password
    class EncryptPassword < CWM::CustomWidget
      def initialize(options)
        textdomain "storage"

        @options = options
      end

      def helptext
        # help text for cryptofs
        helptext = _(
          "<p>\n" \
            "You will need to enter your encryption password.\n" \
          "</p>\n" \
          "<p>\n" \
            "If the encrypted file system does not contain any system file and therefore is\n" \
            "not needed for the update, you may select <b>Skip</b>. In this case, the\n" \
            "file system is not accessed during update.\n" \
          "</p>\n"
        )

        helptext
      end

      def validate
        return true if pw1 == pw2

        Yast::Report.Error(
          _("'Password' and 'Retype password'\ndo not match. Retype the password.")
        )

        Yast::UI.SetFocus(Id(:pw1))

        false
      end

      def store
        @options.password = pw1
      end

      def contents
        Frame(
          _("Encryption Password"),
          MarginBox(
            1.45,
            0.5,
            VBox(
              Password(
                Id(:pw1),
                Opt(:hstretch),
                # Label: get password for user root
                # Please use newline if label is longer than 40 characters
                _("&Enter a Password for your File System:"),
                ""
              ),
              Password(
                Id(:pw2),
                Opt(:hstretch),
                # Label: get same password again for verification
                # Please use newline if label is longer than 40 characters
                _("Reenter the Password for &Verification:"),
                ""
              ),
              VSpacing(0.5)
            )
          )
        )
      end

      def pw1
        Yast::UI.QueryWidget(Id(:pw1), :Value)
      end

      def pw2
        Yast::UI.QueryWidget(Id(:pw2), :Value)
      end
    end
  end
end
