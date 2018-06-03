require "yast"
require "cwm"
require "y2storage"

module Y2Partitioner
  module Widgets
    # Encrypted {Y2Storage::BlkDevice} password
    class EncryptPassword < CWM::CustomWidget
      # Constructor
      def initialize(controller)
        textdomain "storage"

        @controller = controller
        @checker = Y2Storage::EncryptPasswordChecker.new
      end

      # @macro seeAbstractWidget
      def validate
        return true if random_password?

        error_msg = checker.error_msg(pw1, pw2)
        return true unless error_msg

        Yast::Report.Error(error_msg)
        Yast::UI.SetFocus(Id(:pw1))

        false
      end

      # @macro seeAbstractWidget
      def store
        if random_password?
          @controller.random_password = true
        else
          @controller.encrypt_password = pw1
        end
      end

      # @macro seeAbstractWidget
      def cleanup
        checker.tear_down
      end

      # @macro seeCustomWidget
      def contents
        Frame(
          _("Encryption Password"),
          MarginBox(
            1.45,
            0.5,
            form_content
          )
        )
      end

      # @macro seeAbstractWidget
      def help
        # help text for cryptofs
        help_encryption_password + help_skip
      end

    private

      # @return Y2Storage::EncryptPasswordChecker
      attr_reader :checker

      # @return [String]
      def pw1
        Yast::UI.QueryWidget(Id(:pw1), :Value)
      end

      # @return [String]
      def pw2
        Yast::UI.QueryWidget(Id(:pw2), :Value)
      end

      # @return [Boolean]
      def random_password_allowed?
        @random_password_allowed ||= @controller.filesystem_type.to_sym == :swap
      end

      # @return [Boolean]
      def random_password?
        return false unless random_password_allowed?

        Yast::UI::QueryWidget(Id(:pwd_type), :Value) == :random_pwd
      end

      def form_content
        if random_password_allowed?
          extended_content
        else
          password_fields
        end
      end

      def extended_content
        VBox(
          RadioButtonGroup(
            Id(:pwd_type),
            VBox(
              Left(RadioButton(Id(:manual_pwd), _("Ask for password on boot to mount the swap"), true)),
              password_fields,
              Left(RadioButton(Id(:random_pwd), _("Auto-generate a new &random password on every boot"))),
            )
          )
        )
      end

      def password_fields
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
      end

      # @return [String]
      def help_encryption_password
        if random_password_allowed?
          _(
            "<p>\n" \
              "You will need to enter your encryption password or allow to system\n" \
              "auto-generate a new random password on every boot.\n" \
            "</p>\n"
          )
        else
        _(
          "<p>\n" \
            "You will need to enter your encryption password.\n" \
          "</p>\n"
        )
        end
      end

      # @return [String]
      def help_skip
        _(
          "<p>\n" \
            "If the encrypted file system does not contain any system file and therefore is\n" \
            "not needed for the update, you may select <b>Skip</b>. In this case, the\n" \
            "file system is not accessed during update.\n" \
          "</p>\n"
        )
      end
    end
  end
end
