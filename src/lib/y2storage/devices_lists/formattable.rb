#
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

require "storage"

module Y2Storage
  module DevicesLists
    # Mixin for lists of elements that can directly hold a filesystem and, thus,
    # an encryption device
    # @deprecated See DevicesList::Base
    module Formattable
    protected

      # Auxiliar method to avoid iterating the collection twice when looking
      # for filesystems (one for the direct filesystems and another one for
      # filesystems inside an encryption device)
      #
      # @return [Array<Array>]
      def direct_encryptions_and_filesystems
        enc_array = []
        fs_array = []
        list.each do |element|
          child = element.children[0]
          next if child.nil?

          if Storage.blk_filesystem?(child)
            fs_array << Storage.to_blk_filesystem(child)
          elsif Storage.encryption?(child)
            enc_array << Storage.to_encryption(child)
          end
        end

        return enc_array, fs_array
      end
    end
  end
end
