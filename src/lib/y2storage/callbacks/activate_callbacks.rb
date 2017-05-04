#!/usr/bin/env ruby
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
require "y2storage/dialogs/callbacks/activate_luks"

module Y2Storage
  # class to implement callbacks used during activate
  class ActivateCallbacks < Storage::ActivateCallbacks
    include Yast::Logger

    def multipath
      return false
    end

    def luks(uuid, attempt)
      log.info("Trying to open luks UUID: #{uuid} (#{attempt} attempts)")
      dialog = Dialogs::Callbacks::ActivateLuks.new(uuid, attempt)
      result = dialog.run

      activate = result == :accept
      password = activate ? dialog.encryption_password : ""

      Storage::PairBoolString.new(activate, password)
    end
  end
end
