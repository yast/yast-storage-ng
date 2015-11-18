
require "yast"
require "storage"
require "haha"

Yast.import "UI"
Yast.import "Label"

module ExpertPartitioner

  class FormatDialog

    include Yast::UIShortcuts
    include Yast::I18n


    def initialize(sid)
      textdomain "storage"
      @sid = sid
    end


    def run
      return nil unless create_dialog

      begin
        case input = Yast::UI.UserInput
        when :cancel
          nil
        when :ok
          doit
        else
          raise "Unexpected input #{input}"
        end
      ensure
        Yast::UI.CloseDialog
      end
    end

  private

    def create_dialog
      Yast::UI.OpenDialog(
        VBox(
          Heading(_("Format Options")),
          Left(ComboBox(Id(:filesystem),
                        _("Filesystem"), [
                          Item(Id(:ext4), "ext4"),
                          Item(Id(:xfs), "xfs"),
                          Item(Id(:btrfs), "btrfs"),
                          Item(Id(:swap), "swap")
                        ])),
          Left(ComboBox(Id(:mount_point),
                        Opt(:editable, :hstretch),
                        _("Mount Point"),
                        [ "", "test", "/swap" ]
                       )),
          ButtonBox(
            PushButton(Id(:cancel), Yast::Label.CancelButton),
            PushButton(Id(:ok), Yast::Label.OKButton)
          )
        )
      )
    end


    def doit

    end

  end

end
