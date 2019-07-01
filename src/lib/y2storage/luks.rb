# Copyright (c) [2018] SUSE LLC
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

require "y2storage/storage_class_wrapper"
require "y2storage/encryption"

module Y2Storage
  # A LUKS encryption layer on a block device
  #
  # This is a wrapper for Storage::Luks
  class Luks < Encryption
    wrap_class Storage::Luks

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<Luks>] all the LUKS encryption devices in the given devicegraph
    storage_class_forward :all, as: "Luks"

    # @!method uuid
    #   @return [String] UUID of the LUKS device
    storage_forward :uuid

    # Whether the LUKS encryption device matches with a given crypttab spec
    #
    # @see Encryption#match_crypttab_spec?
    #
    # In case of a LUKS device, the second column can also be a value
    # like UUID=111-222-333. In that case, the UUID value refers to the LUKS device
    # instead of the underlying device.
    #
    # @param spec [String] content of the second column of an /etc/crypttab entry
    # @return [Boolean]
    def match_crypttab_spec?(spec)
      if /^UUID=(.*)/ =~ spec
        return !Regexp.last_match(1).empty? && uuid == Regexp.last_match(1)
      end

      super
    end

    protected

    def types_for_is
      super << :luks
    end
  end
end
