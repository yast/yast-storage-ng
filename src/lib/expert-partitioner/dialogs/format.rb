
require "yast"
require "storage"
require "storage/storage-manager"
require "expert-partitioner/popups"

Yast.import "UI"
Yast.import "Label"
Yast.import "Popup"


module ExpertPartitioner

  class FormatDialog

    include Yast::UIShortcuts
    include Yast::I18n
    include Yast::Logger


    def initialize(blk_device)
      textdomain "storage"
      @blk_device = blk_device
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
                          Item(Id(Storage::EXT4), "Ext4"),
                          Item(Id(Storage::XFS), "XFS"),
                          Item(Id(Storage::BTRFS), "Btrfs"),
                          Item(Id(Storage::SWAP), "Swap"),
                          Item(Id(Storage::NTFS), "NTFS"),
                          Item(Id(Storage::VFAT), "VFAT")
                        ])),
          Left(ComboBox(Id(:mount_point),
                        Opt(:editable, :hstretch),
                        _("Mount Point"),
                        [ "", "/test1", "/test2", "/test3", "/test4", "swap" ]
                       )),
          ButtonBox(
            PushButton(Id(:cancel), Yast::Label.CancelButton),
            PushButton(Id(:ok), Yast::Label.OKButton)
          )
        )
      )
    end


    def doit

      storage = Yast::Storage::StorageManager.instance

      staging = storage.staging()

      begin

        log.info "doit #{@blk_device.name}"

        if !RemoveDescendantsPopup.new(@blk_device).run()
          return
        end

        filesystem = @blk_device.create_filesystem(Yast::UI.QueryWidget(:filesystem, :Value))

        mount_point = Yast::UI.QueryWidget(:mount_point, :Value)
        if !mount_point.empty?
          log.info "doit mount-point #{mount_point}"
          filesystem.add_mountpoint(mount_point)
        end

      rescue Storage::DeviceHasWrongType
        log.error "doit on non blk device"
      end

    end

  end

end
