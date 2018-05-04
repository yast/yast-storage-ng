# encoding: utf-8

# Copyright (c) 2018 SUSE LLC
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

require "y2storage/inhibitors/mdadm_auto_assembly"
require "y2storage/inhibitors/udisks_inhibitor"

module Y2Storage
  # class to inhibit various storage subsystem to automatically do things,
  # e.g. mount file systems or assemble RAIDs, that interfere with the
  # operation of YaST
  class Inhibitors
    include Yast::Logger

    def inhibit
      log.info "inhibit"

      @mdadm_auto_assembly.inhibit
      @udisks_inhibitor.inhibit
    end

    def uninhibit
      log.info "uninhibit"

      @udisks_inhibitor.uninhibit
      @mdadm_auto_assembly.uninhibit
    end

  private

    def initialize
      @mdadm_auto_assembly = Y2Storage::MdadmAutoAssembly.new
      @udisks_inhibitor = Y2Storage::UdisksInhibitor.new
    end
  end
end
