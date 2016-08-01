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
require "storage/extensions"
require "expert_partitioner/tab_views/view"
require "expert_partitioner/dialogs/format"
require "expert_partitioner/dialogs/create_partition_table"
require "expert_partitioner/dialogs/create_partition"
require "expert_partitioner/popups"

Yast.import "UI"
Yast.import "Popup"

include Yast::I18n
include Yast::Logger

module ExpertPartitioner
  class LvmVgLvmLvsTabView < TabView
    FIELDS = [:sid, :icon, :name, :lv_name, :size, :stripe_info, :filesystem, :mountpoint]

    def initialize(lvm_vg)
      @lvm_vg = lvm_vg
    end

    def create
      VBox(
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

      @lvm_vg.lvm_lvs.each do |lvm_lv|
        ret << lvm_lv.table_row(FIELDS)
      end

      return ret
    end

    def do_format
      sid = Yast::UI.QueryWidget(Id(:table), :CurrentItem)

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
