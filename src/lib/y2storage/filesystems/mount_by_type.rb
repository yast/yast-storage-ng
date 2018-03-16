# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

require "y2storage/storage_enum_wrapper"

module Y2Storage
  module Filesystems
    # Class to represent all the possible name schemas to use when mounting a
    # filesystem
    #
    # This is a wrapper for the Storage::MountByType enum
    class MountByType
      include StorageEnumWrapper
      include Yast::I18n
      extend Yast::I18n

      wrap_enum "MountByType"

      # Hash with the properties for each mount by type.
      #
      # Keys are the symbols representing the types and values are hashes that
      # can contain:
      # - `:name` for human string
      PROPERTIES = {
        device: {
          name: N_("Device Name")
        },
        id:     {
          name: N_("Device ID")
        },
        label:  {
          name: N_("Volume Label")
        },
        path:   {
          name: N_("Device Path")
        },
        uuid:   {
          name: N_("UUID")
        }
      }.freeze

      # Human readable text for a mount by
      #
      # @note A default value is returned in case there is no a name
      #   defined for the mount by type. The value is translated.
      #
      # @return [String]
      def to_human_string
        textdomain "storage"

        name.nil? ? to_s : _(name)
      end

      # Type corresponding to the given fstab spec
      #
      # @param spec [String] content of the first column of an /etc/fstab entry
      # @return [MountByType, nil] nil if the string doesn't match any known format
      def self.from_fstab_spec(spec)
        if spec.start_with?("UUID=", "/dev/disk/by-uuid/")
          UUID
        elsif spec.start_with?("LABEL=", "/dev/disk/by-label/")
          LABEL
        elsif spec.start_with?("/dev/disk/by-id/")
          ID
        elsif spec.start_with?("/dev/disk/by-path/")
          PATH
        elsif spec.start_with?("/dev/")
          DEVICE
        end
      end

    private

      # Name of the mount by type, if defined
      #
      # @return [String, nil] nil if the name is not defined.
      def name
        return nil if PROPERTIES[to_sym].nil?

        PROPERTIES[to_sym][:name]
      end
    end
  end
end
