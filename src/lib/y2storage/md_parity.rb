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
  # Class to represent all the possible MD parities
  #
  # This is a wrapper for the Storage::MdParity enum
  class MdParity
    include StorageEnumWrapper
    include Yast::I18n
    extend Yast::I18n

    wrap_enum "MdParity"

    TRANSLATIONS = {
      # TODO: should be tested by some real OPS guy, I (JR) pick human wording from `man mdadm`
      default:            N_("Default"),
      left_asymmetric:    N_("Left asymmetric"),
      left_symmetric:     N_("Left symmetric"),
      right_asymmetric:   N_("Right asymmetric"),
      right_symmetric:    N_("Right symmetric"),
      first:              N_("Parity first"),
      last:               N_("Parity last"),

      # note parity with _6 suffix is for converting raid 5 to 6 and is only intermediate state
      left_asymmetric_6:  N_("Left asymmetric RAID6"),
      left_symmetric_6:   N_("Left symmetric RAID6"),
      right_asymmetric_6: N_("Right asymmetric RAID6"),
      right_symmetric_6:  N_("Right symmetric RAID6"),
      first_6:            N_("Parity first RAID6"),
      last_6:             N_("Parity last RAID6"),

      near_2:             N_("Two copies near"),
      near_3:             N_("Three copies near"),
      offset_2:           N_("Two copies offset"),
      offset_3:           N_("Three copies offset"),
      far_2:              N_("Two copies far"),
      far_3:              N_("Three copies far")
    }
    private_constant :TRANSLATIONS

    # Returns human readable representation of enum.
    # @return [String]
    # @raise [RuntimeError] when called on unknown ennum value.
    def to_human_string
      textdomain "storage"

      string = TRANSLATIONS[to_sym] or raise "Unhandled MD raid parity value '#{inspect}'"

      _(string)
    end
  end
end
