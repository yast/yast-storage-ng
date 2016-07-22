# encoding: utf-8

# Copyright (c) [2015-2016] SUSE LLC
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
require "storage/extensions"
require "expert_partitioner/tree_views/view"
require "expert_partitioner/dialogs/format"
require "expert_partitioner/popups"

Yast.import "UI"
Yast.import "Popup"

include Yast::I18n
include Yast::Logger

module ExpertPartitioner
  class LvmVgsTreeView < TreeView
    FIELDS = [:sid, :icon, :name, :size]

    def initialize
      storage = Yast::Storage::StorageManager.instance
      staging = storage.staging
      @lvm_vgs = staging.all_lvm_vgs
    end

    def create
      VBox(
        Left(IconAndHeading(_("LVM VGs"), Icons::LVM_VG)),
        Table(Id(:table), Opt(:keepSorting), Storage::Device.table_header(FIELDS), items),
        HBox(
          PushButton(Id(:format), _("Format...")),
          HStretch()
        )
      )
    end

    def handle(input)
      case input

      when :format
        do_format

      end
    end

  private

    def items
      ret = []

      @lvm_vgs.each do |lvm_vg|

        ret << lvm_vg.table_row(FIELDS)

        lvm_vg.lvm_lvs.each do |lvm_lv|
          ret << lvm_lv.table_row(FIELDS)
        end

      end

      return ret
    end

    def do_format
      sid = Yast::UI.QueryWidget(Id(:table), :CurrentItem)

      storage = Yast::Storage::StorageManager.instance
      staging = storage.staging
      device = staging.find_device(sid)

      begin
        blk_device = Storage.to_blk_device(device)
        log.info "do_format #{sid} #{blk_device.name}"
        FormatDialog.new(blk_device).run
      rescue Storage::DeviceHasWrongType
        log.error "do_format on non blk device"
      end

      update(true)
    end
  end
end
