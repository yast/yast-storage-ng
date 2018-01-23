# encoding: utf-8

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

require "yast"
require "y2storage"

module Y2Partitioner
  # Mixin for all those partitioner components that parse sizes entered by the
  # user.
  #
  # Provided as a way to centralize the configuration of such parsing (e.g.
  # considering International System units as base 2 units) and error handling
  # (e.g. the user leaves the field empty or enters some crazy stuff).
  module SizeParser
    # Converts a string to DiskSize, returning nil if the conversion
    # it is not possible
    #
    # @see Y2Storage::DiskSize#from_human_string
    #
    # @return [Y2Storage::DiskSize, nil]
    def parse_user_size(string)
      return nil if string.nil?
      Y2Storage::DiskSize.from_human_string(string, legacy_units: true)
    rescue TypeError
      nil
    end
  end
end
