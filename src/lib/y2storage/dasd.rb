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

require "y2storage/storage_class_wrapper"
require "y2storage/partitionable"

module Y2Storage
  # A DASD (direct-access storage device), typically used in mainframes
  #
  # This is a wrapper for Storage::Dasd
  class Dasd < Partitionable
    wrap_class Storage::Dasd

    storage_forward :rotational?, to: :rotational
    storage_forward :dasd_type, as: "DasdType"
    storage_forward :dasd_format, as: "DasdFormat"

    storage_class_forward :create, as: "Dasd"
    storage_class_forward :all, as: "Dasd"
    storage_class_forward :find_by_name, as: "Dasd"

    def inspect
      "<Dasd #{name} #{size}>"
    end

  protected

    def types_for_is
      super << :dasd
    end
  end
end
