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
require "y2storage"
require "storage/extensions"
require "expert_partitioner/tab_views/view"
require "expert_partitioner/popups"

Yast.import "UI"
Yast.import "Popup"

include Yast::I18n
include Yast::Logger

module ExpertPartitioner
  class MdDevicesTabView < TabView
    FIELDS = [:sid, :icon, :name, :size, :spare, :faulty]

    def initialize(md)
      @md = md
    end

    def create
      VBox(
        Table(Id(:table), Opt(:keepSorting), Storage::Device.table_header(FIELDS), items)
      )
    end

  private

    def items
      ret = []

      blk_devices = @md.devices

      blk_devices.each do |blk_device|
        blk_device = Storage.downcast(blk_device)
        ret << blk_device.table_row(FIELDS)
      end

      return ret
    end
  end
end
