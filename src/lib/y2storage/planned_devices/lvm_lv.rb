#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015-2017] SUSE LLC
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
require "y2storage/planned_devices/base"
require "y2storage/planned_devices/mixins"

module Y2Storage
  module PlannedDevices
    # Specification for a Y2Storage::LvmLv object to be created during the
    # storage or AutoYaST proposals
    #
    # @see Base
    class LvmLv < Base
      include PlannedDevices::HasSize
      include PlannedDevices::CanBeFormatted
      include PlannedDevices::CanBeMounted
      include PlannedDevices::CanBeEncrypted

      # @return [String] name to use for Y2Storage::LvmLv#lv_name
      attr_accessor :logical_volume_name

      # Constructor.
      #
      # @param mount_point [string] See {CanBeMounted#mount_point}
      # @param filesystem_type [Filesystems::Type] See {CanBeFormatted#filesystem_type}
      def initialize(mount_point, filesystem_type = nil)
        initialize_has_size
        initialize_can_be_formatted
        initialize_can_be_mounted
        initialize_can_be_encrypted

        @mount_point = mount_point
        @filesystem_type = filesystem_type

        return unless @mount_point && @mount_point.start_with?("/")

        @logical_volume_name =
          if @mount_point == "/"
            "root"
          else
            @mount_point.sub(%r{^/}, "")
          end
      end

      def self.to_string_attrs
        [:mount_point, :reuse, :min_size, :max_size, :logical_volume_name, :subvolumes]
      end
    end
  end
end
