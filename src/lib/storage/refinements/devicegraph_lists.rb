#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

require "storage"
require "storage/disks_list"
require "storage/partitions_list"
require "storage/filesystems_list"
require "storage/free_disk_spaces_list"

module Yast
  module Storage
    module Refinements
      # Refinement for ::Storage::Devicegraph adding shortcuts to the devices
      # lists
      module DevicegraphLists
        refine ::Storage::Devicegraph do
          DEVICE_LISTS = {
            disks:            DisksList,
            partitions:       PartitionsList,
            filesystems:      FilesystemsList,
            free_disk_spaces: FreeDiskSpacesList
          }

          DEVICE_LISTS.each do |list, klass|
            define_method(list) do
              klass.new(self)
            end
          end
        end
      end
    end
  end
end
