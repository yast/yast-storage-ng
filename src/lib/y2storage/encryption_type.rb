# Copyright (c) [2019] SUSE LLC
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
  # Class to represent all the possible encryption types implemented by libstorage
  #
  # This is a wrapper for the Storage::EncryptionType enum
  class EncryptionType
    include StorageEnumWrapper
    include Yast::I18n
    extend Yast::I18n

    wrap_enum "EncryptionType"

    TRANSLATIONS = {
      unknown:        N_("Unknown encryption"),
      none:           N_("No encryption"),
      twofish:        N_("Twofish"),
      twofish_old:    N_("Old Twofish (loop_fish2)"),
      twofish256_old: N_("Old Twofish (loop_fish2) 256-bit"),
      luks1:          N_("LUKS1"),
      luks2:          N_("LUKS2")
    }
    private_constant :TRANSLATIONS

    # Returns human readable representation of enum which is already translated.
    #
    # @raise [RuntimeError] when called on enum value for which translation is not yet defined.
    # @return [String]
    def to_human_string
      textdomain "storage"

      string = TRANSLATIONS[to_sym] or raise "Unhandled encryption type '#{inspect}'"

      _(string)
    end
  end
end
