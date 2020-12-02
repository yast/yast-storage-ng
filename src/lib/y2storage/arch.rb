# Copyright (c) [2019-2020] SUSE LLC
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

module Y2Storage
  # Hardware architecture
  #
  # This is a wrapper for Storage::Arch
  class Arch
    include StorageClassWrapper

    wrap_class Storage::Arch

    # @!method x86?
    #   @return [Boolean] whether the architecture is x86
    storage_forward :x86?

    # @!method ppc?
    #   @return [Boolean] whether the architecture is PowerPC
    storage_forward :ppc?

    # @!method s390?
    #   @return [Boolean] whether the architecture is s390
    storage_forward :s390?

    # @!method efiboot?
    #   @return [Boolean] whether it is an UEFI system
    storage_forward :efiboot?

    # @!method ppc_power_nv?
    #   @return [Boolean] whether it is a Power NV system
    storage_forward :ppc_power_nv?

    # @!method page_size
    #   @return [Integer] the system page size
    storage_forward :page_size
  end
end
