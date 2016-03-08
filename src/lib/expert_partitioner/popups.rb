# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
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
require "storage"
require "storage/storage_manager"

Yast.import "UI"
Yast.import "Label"
Yast.import "Popup"

module ExpertPartitioner
  # Popup to ask for confirmation before deleting the descendants of a device
  class RemoveDescendantsPopup
    def initialize(device)
      textdomain "storage"
      @device = device
    end

    def run
      return true if @device.num_children == 0

      log.info "removing all descendants"
      descendants = @device.descendants(false)

      tmp = descendants.to_a.map(&:to_s).join("\n")
      return false unless Yast::Popup::YesNo("Will delete:\n#{tmp}")

      @device.remove_descendants

      return true
    end
  end
end
