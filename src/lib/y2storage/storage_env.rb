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
require "singleton"

module Y2Storage
  # Class to read ENV values for storage
  class StorageEnv
    include Singleton
    include Yast::Logger

    ENV_MULTIPATH = "LIBSTORAGE_MULTIPATH_AUTOSTART".freeze

    ENV_BIOS_RAID = "LIBSTORAGE_MDPART".freeze

    private_constant :ENV_MULTIPATH, :ENV_BIOS_RAID

    def initialize
      @active_cache = {}
    end

    # Whether the activation of multipath has been forced via the
    # LIBSTORAGE_MULTIPATH_AUTOSTART boot parameter
    #
    # See https://en.opensuse.org/SDB:Linuxrc for details and see
    # bsc#1082542 for an example of scenario in which this is needed.
    #
    # @return [Boolean]
    def forced_multipath?
      active?(ENV_MULTIPATH)
    end

    # Whether the probed MD RAIDS has been forced to be consider BIOS RAIDS
    # via the LIBSTORAGE_MDPART boot parameter
    #
    # See bsc#1092417 for an example of scenario in which this is needed.
    #
    # @return [Boolean]
    def forced_bios_raid?
      active?(ENV_BIOS_RAID)
    end

  private

    # Whether the env variable is active
    #
    # @param variable [String]
    # @return [Boolean]
    def active?(variable)
      return @active_cache[variable] if @active_cache.key?(variable)

      value = read(variable)
      result = if value
        # Similar to what linuxrc does, also consider the flag activated if the
        # variable is used with no value or with "1"
        value.casecmp?("on") || value.empty? || value == "1"
      else
        false
      end
      @active_cache[variable] = result
    end

    # Read an ENV variable
    #
    # @param variable [String]
    # @return [String, nil]
    def read(variable)
      # Sort the keys to have a deterministic behavior and to prefer
      # all-uppercase over the other variants, then do a case insensitive
      # search
      key = ENV.keys.sort.find { |k| k.match(/\A#{variable}\z/i) }
      return nil unless key

      log.debug "Found ENV variable: #{key.inspect}"
      ENV[key]
    end
  end
end
