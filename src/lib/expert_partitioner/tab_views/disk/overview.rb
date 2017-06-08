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
require "expert_partitioner/tab_views/view"
require "expert_partitioner/popups"

Yast.import "UI"
Yast.import "Popup"

include Yast::I18n
include Yast::Logger

module ExpertPartitioner
  class DiskOverviewTabView < TabView
    def initialize(disk)
      @disk = disk
    end

    def create
      tmp = ["Name: #{@disk.name}",
             "Size: #{@disk.size.to_human_string}"]

      @disk.udev_paths.each_with_index do |udev_path, i|
        tmp << "Device Path #{i + 1}: #{udev_path}"
      end

      @disk.udev_ids.each_with_index do |udev_id, i|
        tmp << "Device ID #{i + 1}: #{udev_id}"
      end

      contents = Yast::HTML.List(tmp)

      return RichText(Id(:text), Opt(:hstretch, :vstretch), contents)
    end
  end
end
