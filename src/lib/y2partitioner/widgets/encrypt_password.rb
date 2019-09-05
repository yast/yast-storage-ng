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
      def help
        # help text for cryptofs
        _(
          "<p>\n" \
            "You will need to enter your encryption password.\n" \
          "</p>\n" \
          "<p>\n" \
            "If the encrypted file system does not contain any system file and therefore is\n" \
            "not needed for the update, you may select <b>Skip</b>. In this case, the\n" \
            "file system is not accessed during update.\n" \
          "</p>\n"
        )
      end

      # @macro seeAbstractWidget
      def validate
        msg = checker.error_msg(pw1, pw2) if enabled?
        return true unless msg

        Yast::Report.Error(msg)
        Yast::UI.SetFocus(Id(:pw1))
        false
      end

      # @macro seeAbstractWidget
      def store
        @controller.password = pw1
      end

      # @macro seeAbstractWidget
      def cleanup
        checker.tear_down
      end

      # @macro seeCustomWidget
      def contents
        VBox(
          Id(widget_id),
          Password(
            Id(:pw1),
            Opt(:hstretch),
            _("&Enter an Encryption Password:"),
            @controller.password
          ),
          Password(
            Id(:pw2),
            Opt(:hstretch),
            _("Reenter the Password for &Verification:"),
            @controller.password
          )
        )
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
    end
  end
end
