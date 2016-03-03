# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
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
require "storage"
require "storage/storage_manager"
require "expert_partitioner/popups"

Yast.import "UI"
Yast.import "Label"
Yast.import "Popup"

module ExpertPartitioner
  # UI dialog to format (create a filesystem) a given block device
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
          Left(ComboBox(Id(:filesystem), _("Filesystem"), filesystem_items)),
          Left(
            ComboBox(
              Id(:mount_point),
              Opt(:editable, :hstretch),
              _("Mount Point"),
              ["", "/test1", "/test2", "/test3", "/test4", "swap"]
            )
          ),
          ButtonBox(
            PushButton(Id(:cancel), Yast::Label.CancelButton),
            PushButton(Id(:ok), Yast::Label.OKButton)
          )
        )
      )
    end

    def filesystem_items
      [
        Item(Id(Storage::FsType_EXT4), "Ext4"),
        Item(Id(Storage::FsType_XFS), "XFS"),
        Item(Id(Storage::FsType_BTRFS), "Btrfs"),
        Item(Id(Storage::FsType_SWAP), "Swap"),
        Item(Id(Storage::FsType_NTFS), "NTFS"),
        Item(Id(Storage::FsType_VFAT), "VFAT")
      ]
    end

    def doit
      log.info "doit #{@blk_device.name}"

      return if !RemoveDescendantsPopup.new(@blk_device).run

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
