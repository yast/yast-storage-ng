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

require "storage/extensions"
require "expert_partitioner/tree_views/view"
require "expert_partitioner/icons"

Yast.import "UI"
Yast.import "HTML"

include Yast::I18n

module ExpertPartitioner
  class PartitionTreeView < TreeView
    def initialize(partition)
      textdomain "storage-ng"
      @partition = partition
    end

    def create
      tmp = ["Name: #{@partition.name}",
             "Size: #{::Storage.byte_to_humanstring(@partition.size.to_i, false, 2, false)}"]

      @partition.udev_paths.each_with_index do |udev_path, i|
        tmp << "Device Path #{i + 1}: #{udev_path}"
      end

      @partition.udev_ids.each_with_index do |udev_id, i|
        tmp << "Device ID #{i + 1}: #{udev_id}"
      end

      contents = Yast::HTML.List(tmp)

      # FIXME: Add a describing comment, that helps translators to learn
      # about the context of the strings.
      VBox(
        Left(IconAndHeading(_("Partition: %s") % @partition.name, Icons::PARTITION)),
        RichText(Id(:text), Opt(:hstretch, :vstretch), contents)
      )
    end
  end
end
